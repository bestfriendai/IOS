//
//  ContentView.swift
//  StreamyyyApp
//
//  Modern entry point with enhanced UI/UX
//

import SwiftUI
import AVFoundation

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
    @StateObject private var twitchService = RealTwitchAPIService.shared
    @State private var searchText = ""
    @State private var featuredStreams: [TwitchStream] = []
    @State private var isLoading = false
    
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
                                .submitLabel(.search)
                                .onSubmit {
                                    searchStreams()
                                }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                        
                        // Featured Streams Section
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(searchText.isEmpty ? "Top Live Streams" : "Search Results")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    if !featuredStreams.isEmpty {
                                        Text("\(featuredStreams.count) streams")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                                Spacer()
                                Button(action: {
                                    if searchText.isEmpty {
                                        loadFeaturedStreams()
                                    } else {
                                        searchStreams()
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.cyan)
                                }
                            }
                            
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                    .frame(height: 100)
                            } else if featuredStreams.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "tv.slash")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white.opacity(0.4))
                                    
                                    VStack(spacing: 8) {
                                        Text(searchText.isEmpty ? "No streams available" : "No results found")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        Text(searchText.isEmpty ? "Try refreshing or check back later" : "Try a different search term")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.6))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(height: 150)
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 12) {
                                    ForEach(featuredStreams, id: \.id) { stream in
                                        TwitchStreamCard(stream: stream)
                                    }
                                }
                            }
                        }
                        
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
            .onAppear {
                loadFeaturedStreams()
            }
        }
    }
    
    private func searchStreams() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            loadFeaturedStreams()
            return
        }
        
        isLoading = true
        Task {
            // For now, we'll filter the current streams by search text
            // In a real implementation, you might want to call a search API
            let result = await twitchService.getTopStreams(first: 100)
            let filtered = result.streams.filter { stream in
                stream.title.localizedCaseInsensitiveContains(searchText) ||
                stream.userName.localizedCaseInsensitiveContains(searchText) ||
                stream.gameName.localizedCaseInsensitiveContains(searchText)
            }
            
            await MainActor.run {
                featuredStreams = filtered
                isLoading = false
            }
        }
    }
    
    private func loadFeaturedStreams() {
        isLoading = true
        Task {
            let result = await twitchService.getTopStreams(first: 20)
            await MainActor.run {
                featuredStreams = result.streams
                isLoading = false
            }
        }
    }
}

struct MultiStreamTabView: View {
    @State private var streamSlots: [StreamSlot] = Array(repeating: StreamSlot(), count: 4)
    @State private var currentLayout: LayoutType = .grid2x2
    @State private var showingStreamPicker = false
    @State private var selectedSlotIndex = 0
    @State private var showingFullscreen = false
    @State private var fullscreenSlot: StreamSlot?
    @State private var activeAudioSlotIndex: Int? = nil // Track which slot has audio enabled
    
    enum LayoutType {
        case single, grid2x2, grid3x3, pip
        
        var gridColumns: Int {
            switch self {
            case .single: return 1
            case .grid2x2: return 2
            case .grid3x3: return 3
            case .pip: return 2
            }
        }
        
        var slotCount: Int {
            switch self {
            case .single: return 1
            case .grid2x2: return 4
            case .grid3x3: return 9
            case .pip: return 2
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Layout Controls
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Multi-Stream")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            let activeCount = streamSlots.prefix(currentLayout.slotCount).filter { $0.hasStream }.count
                            Text("\(activeCount)/\(currentLayout.slotCount) streams active")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        // Controls
                        HStack(spacing: 8) {
                            // Quick add stream button
                            Button {
                                selectedSlotIndex = streamSlots.firstIndex { !$0.hasStream } ?? 0
                                showingStreamPicker = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.cyan)
                            }
                            .disabled(streamSlots.prefix(currentLayout.slotCount).allSatisfy { $0.hasStream })
                            
                            // Layout picker
                            LayoutButton(layout: .grid2x2, current: currentLayout) {
                                currentLayout = .grid2x2
                                updateStreamSlots()
                            }
                            LayoutButton(layout: .grid3x3, current: currentLayout) {
                                currentLayout = .grid3x3
                                updateStreamSlots()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Stream Grid
                    GeometryReader { geometry in
                        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: currentLayout.gridColumns)
                        let availableHeight = geometry.size.height - 16 // Account for padding
                        let availableWidth = geometry.size.width - 16
                        
                        // Calculate appropriate height for each stream slot
                        let slotHeight: CGFloat = {
                            switch currentLayout {
                            case .grid2x2:
                                return (availableHeight - 8) / 2 // 8 for spacing between rows
                            case .grid3x3:
                                return (availableHeight - 16) / 3 // 16 for spacing between rows
                            default:
                                return availableHeight
                            }
                        }()
                        
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(0..<currentLayout.slotCount, id: \.self) { index in
                                StreamSlotView(
                                    slot: index < streamSlots.count ? streamSlots[index] : StreamSlot(),
                                    slotIndex: index,
                                    isMuted: isSlotMuted(index),
                                    onTap: {
                                        selectedSlotIndex = index
                                        showingStreamPicker = true
                                    },
                                    onToggleMute: {
                                        toggleExclusiveAudio(for: index)
                                    }
                                )
                                .frame(height: slotHeight)
                                .contextMenu {
                                    if index < streamSlots.count && streamSlots[index].hasStream {
                                        Button("Replace Stream") {
                                            selectedSlotIndex = index
                                            showingStreamPicker = true
                                        }
                                        Button("Remove Stream") {
                                            streamSlots[index] = StreamSlot()
                                        }
                                        Button(isSlotMuted(index) ? "Unmute" : "Mute") {
                                            toggleExclusiveAudio(for: index)
                                        }
                                    } else {
                                        Button("Add Stream") {
                                            selectedSlotIndex = index
                                            showingStreamPicker = true
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingStreamPicker) {
                StreamPickerView(selectedSlot: $selectedSlotIndex, streamSlots: $streamSlots)
            }
        }
    }
    
    private func updateStreamSlots() {
        let neededSlots = currentLayout.slotCount
        if streamSlots.count < neededSlots {
            streamSlots.append(contentsOf: Array(repeating: StreamSlot(), count: neededSlots - streamSlots.count))
        }
    }
    
    private func toggleExclusiveAudio(for slotIndex: Int) {
        // If this slot is already the active audio slot, mute it
        if activeAudioSlotIndex == slotIndex {
            activeAudioSlotIndex = nil
        } else {
            // Otherwise, make this slot the only unmuted one
            activeAudioSlotIndex = slotIndex
        }
    }
    
    private func isSlotMuted(_ slotIndex: Int) -> Bool {
        return activeAudioSlotIndex != slotIndex
    }
}

struct LibraryTabView: View {
    @State private var favorites: [ContentViewStream] = ContentViewStream.sampleStreams.prefix(3).map { $0 }
    @State private var recentStreams: [ContentViewStream] = ContentViewStream.sampleStreams.suffix(2).map { $0 }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Library")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Your saved streams and viewing history")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Favorites Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("Favorites")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(favorites.count) streams")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(favorites, id: \.id) { stream in
                                    ContentStreamCard(stream: stream)
                                }
                            }
                        }
                        
                        // Recent Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("Recently Watched")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(recentStreams, id: \.id) { stream in
                                    HStack {
                                        AsyncImage(url: URL(string: stream.thumbnailUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: 80, height: 45)
                                        .cornerRadius(8)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(stream.title)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .lineLimit(2)
                                            
                                            Text(stream.streamerName)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(stream.viewerCount) viewers")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.ultraThinMaterial)
                                    )
                                }
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

struct ProfileTabView: View {
    @State private var showingSettings = false
    @State private var showingAuth = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
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
                                
                                Text("Sign in to sync your streams across devices")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button("Sign In") {
                                showingAuth = true
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            
                            Button("Settings") {
                                showingSettings = true
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        // Stats Section
                        VStack(spacing: 16) {
                            Text("Your Stats")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack {
                                StatCard(title: "Streams Watched", value: "24")
                                StatCard(title: "Hours Watched", value: "12.5")
                                StatCard(title: "Favorites", value: "8")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAuth) {
                AuthenticationSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
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

// MARK: - Supporting Types and Views

import WebKit

struct TwitchStreamPlayer: UIViewRepresentable {
    let channelName: String
    @Binding var isMuted: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        
        // Multi-stream configuration - allow simultaneous audio
        configuration.suppressesIncrementalRendering = false
        configuration.allowsAirPlayForMediaPlayback = false
        
        // Enhanced configuration based on working multi-stream-viewer approach (iOS compatible)
        configuration.preferences.javaScriptEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Enable modern web features for better compatibility
        if #available(iOS 14.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Use separate process pool for each stream to enable simultaneous playback
        configuration.processPool = WKProcessPool()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Configure audio session for playback
        setupAudioSession()
        
        // Use the proven approach from working multi-stream-viewer
        let playerHTML = createWorkingPlayerHTML()
        webView.loadHTMLString(playerHTML, baseURL: URL(string: "https://localhost"))
        
        print("🎥 Starting Twitch player for channel: \(channelName) using proven multi-stream-viewer approach")
        return webView
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            print("🔊 Audio session configured for playback with mixing")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only update mute state without reloading - avoid full player reconstruction
        let muteJS = """
        try {
            console.log('🔊 SwiftUI requesting mute state change to:', \(isMuted));
            
            // IMPORTANT: Only update mute state, never reload the player
            if (window.updateMute && typeof window.updateMute === 'function') {
                console.log('🔊 Using window.updateMute function');
                window.updateMute(\(isMuted));
            } else if (window.twitchPlayer && typeof window.twitchPlayer.setMuted === 'function') {
                console.log('🔊 Using direct twitchPlayer.setMuted');
                window.twitchPlayer.setMuted(\(isMuted));
                if (!\(isMuted) && typeof window.twitchPlayer.setVolume === 'function') {
                    window.twitchPlayer.setVolume(0.7);
                    console.log('🔊 Set volume to 0.7');
                }
            } else if (window.twitchEmbedPlayer && typeof window.twitchEmbedPlayer.getPlayer === 'function') {
                console.log('🔊 Using embed player');
                var videoPlayer = window.twitchEmbedPlayer.getPlayer();
                if (videoPlayer && typeof videoPlayer.setMuted === 'function') {
                    videoPlayer.setMuted(\(isMuted));
                    if (!\(isMuted) && typeof videoPlayer.setVolume === 'function') {
                        videoPlayer.setVolume(0.7);
                        console.log('🔊 Set embed volume to 0.7');
                    }
                    }
            } else {
                console.log('🔊 No player instances available for mute control');
                // DO NOT reload iframe - just log that mute control is not available
                // Reloading iframe causes the entire stream to restart
            }
            console.log('🔊 Mute update completed without reloading');
        } catch(e) {
            console.error('🔊 Mute update error:', e);
        }
        """
        
        webView.evaluateJavaScript(muteJS) { result, error in
            if let error = error {
                print("❌ JavaScript error: \(error)")
            } else {
                print("🔊 Mute update sent for \(channelName): \(isMuted)")
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createWorkingPlayerHTML() -> String {
        let muteParam = isMuted ? "true" : "false"
        let bundleId = Bundle.main.bundleIdentifier ?? "localhost"
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no, user-scalable=no">
            <style>
                html, body {
                    margin: 0; padding: 0; width: 100%; height: 100%;
                    background-color: black; overflow: hidden;
                }
                #twitch-embed { width: 100%; height: 100%; }
                .status {
                    position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
                    color: #fff; font-family: Arial, sans-serif; font-size: 12px;
                    text-align: center; z-index: 100; padding: 10px;
                }
                .error { color: #ff4444; }
            </style>
        </head>
        <body>
            <div id="status" class="status">Loading stream...</div>
            <div id="twitch-embed"></div>
            <script src="https://embed.twitch.tv/embed/v1.js"></script>
            <script>
                console.log('🎥 Initializing Twitch player for: \(channelName.lowercased())');
                
                var status = document.getElementById('status');
                var embedContainer = document.getElementById('twitch-embed');
                var currentMethod = 0;
                
                // Multi-method approach based on working multi-stream-viewer
                var streamingMethods = [
                    {
                        name: 'Embed API with localhost',
                        execute: function() {
                            if (typeof Twitch !== 'undefined' && Twitch.Embed) {
                                var player = new Twitch.Embed('twitch-embed', {
                                    width: '100%',
                                    height: '100%',
                                    channel: '\(channelName.lowercased())',
                                    parent: ['localhost'],
                                    autoplay: true,
                                    muted: \(muteParam),
                                    controls: false,
                                    playsinline: true,
                                    allowfullscreen: false,
                                    layout: 'video'
                                });
                                
                                player.addEventListener(Twitch.Embed.VIDEO_READY, function() {
                                    console.log('✅ Embed API working - video ready');
                                    hideStatus();
                                    
                                    // Store both embed and video player instances
                                    window.twitchEmbedPlayer = player;
                                    window.twitchPlayer = player.getPlayer();
                                    
                                    // Enable audio for multi-stream
                                    var videoPlayer = player.getPlayer();
                                    if (videoPlayer && videoPlayer.setMuted) {
                                        videoPlayer.setMuted(\(muteParam));
                                        console.log('🔊 Initial mute state set to:', \(muteParam));
                                        // Allow volume for multi-stream (each stream can have independent audio)
                                        if (!(\(muteParam)) && videoPlayer.setVolume) {
                                            videoPlayer.setVolume(0.7); // Set reasonable volume for multi-stream
                                            console.log('🔊 Initial volume set to 0.7');
                                        }
                                    }
                                });
                                
                                // Also listen for when video actually starts playing
                                player.addEventListener(Twitch.Embed.VIDEO_PLAY, function() {
                                    console.log('✅ Video started playing - hiding status');
                                    hideStatus();
                                });
                                
                                player.addEventListener(Twitch.Embed.VIDEO_ERROR, function() {
                                    console.log('❌ Embed API failed, trying next method');
                                    tryNextMethod();
                                });
                                
                                return true;
                            }
                            return false;
                        }
                    },
                    {
                        name: 'Direct iframe with localhost',
                        execute: function() {
                            embedContainer.innerHTML = '<iframe src="https://player.twitch.tv/?channel=\(channelName.lowercased())&parent=localhost&muted=\(muteParam)&autoplay=true&controls=false" width="100%" height="100%" frameborder="0" allowfullscreen></iframe>';
                            
                            // Better iframe load detection with multiple methods
                            var iframe = embedContainer.querySelector('iframe');
                            if (iframe) {
                                // Method 1: onload event
                                iframe.onload = function() {
                                    console.log('✅ Direct iframe method loaded via onload');
                                    hideStatus();
                                };
                                
                                // Method 2: Check if iframe content is accessible (cross-origin safe)
                                var checkLoaded = function() {
                                    try {
                                        if (iframe.contentWindow) {
                                            console.log('✅ Direct iframe content window available');
                                            hideStatus();
                                            return true;
                                        }
                                    } catch(e) {
                                        // Cross-origin, but that's expected and means it loaded
                                        console.log('✅ Direct iframe loaded (cross-origin expected)');
                                        hideStatus();
                                        return true;
                                    }
                                    return false;
                                };
                                
                                // Check immediately and then periodically
                                if (!checkLoaded()) {
                                    var checkInterval = setInterval(function() {
                                        if (checkLoaded()) {
                                            clearInterval(checkInterval);
                                        }
                                    }, 500);
                                    
                                    // Clear interval after timeout
                                    setTimeout(function() {
                                        clearInterval(checkInterval);
                                    }, 5000);
                                }
                                
                                // Fallback timeout - always hide after reasonable time
                                setTimeout(function() {
                                    console.log('✅ Direct iframe timeout - hiding status');
                                    hideStatus();
                                }, 2000); // Reduced to 2 seconds for better UX
                            }
                            return true;
                        }
                    },
                    {
                        name: 'Fallback iframe with twitch.tv',
                        execute: function() {
                            embedContainer.innerHTML = '<iframe src="https://player.twitch.tv/?channel=\(channelName.lowercased())&parent=twitch.tv&muted=\(muteParam)&autoplay=true&controls=false" width="100%" height="100%" frameborder="0" allowfullscreen></iframe>';
                            
                            // Better iframe load detection with multiple methods
                            var iframe = embedContainer.querySelector('iframe');
                            if (iframe) {
                                iframe.onload = function() {
                                    console.log('✅ Fallback iframe method loaded via onload');
                                    hideStatus();
                                };
                                
                                // Check for content window availability
                                var checkLoaded = function() {
                                    try {
                                        if (iframe.contentWindow) {
                                            console.log('✅ Fallback iframe content available');
                                            hideStatus();
                                            return true;
                                        }
                                    } catch(e) {
                                        console.log('✅ Fallback iframe loaded (cross-origin expected)');
                                        hideStatus();
                                        return true;
                                    }
                                    return false;
                                };
                                
                                if (!checkLoaded()) {
                                    var checkInterval = setInterval(function() {
                                        if (checkLoaded()) {
                                            clearInterval(checkInterval);
                                        }
                                    }, 500);
                                    
                                    setTimeout(function() {
                                        clearInterval(checkInterval);
                                    }, 5000);
                                }
                                
                                // Always hide loading after reasonable time
                                setTimeout(function() {
                                    console.log('✅ Fallback iframe timeout - hiding status');
                                    hideStatus();
                                }, 2000);
                            }
                            return true;
                        }
                    },
                    {
                        name: 'Bundle ID iframe',
                        execute: function() {
                            embedContainer.innerHTML = '<iframe src="https://player.twitch.tv/?channel=\(channelName.lowercased())&parent=\(bundleId)&muted=\(muteParam)&autoplay=true&controls=false" width="100%" height="100%" frameborder="0" allowfullscreen></iframe>';
                            setTimeout(function() {
                                console.log('✅ Bundle ID iframe method loaded');
                                hideStatus();
                            }, 2000);
                            return true;
                        }
                    }
                ];
                
                function hideStatus() {
                    status.style.display = 'none';
                }
                
                function showError() {
                    status.innerHTML = 'Stream unavailable';
                    status.className = 'status error';
                }
                
                function tryNextMethod() {
                    if (currentMethod < streamingMethods.length) {
                        var method = streamingMethods[currentMethod];
                        console.log('🔄 Trying method: ' + method.name);
                        status.innerHTML = 'Loading (' + (currentMethod + 1) + '/' + streamingMethods.length + ')...';
                        
                        if (method.execute()) {
                            currentMethod++;
                            
                            // Shorter timeout for faster fallback, but with better detection
                            setTimeout(function() {
                                if (status.style.display !== 'none') {
                                    console.log('⏰ Method timeout, trying next...');
                                    tryNextMethod();
                                }
                            }, 3000); // Reduced from 4000ms
                        } else {
                            currentMethod++;
                            tryNextMethod();
                        }
                    } else {
                        console.log('❌ All methods failed');
                        showError();
                    }
                }
                
                // Enhanced mute control functions - NO RELOADING
                window.updateMute = function(muted) {
                    console.log('🔊 Setting mute to:', muted);
                    
                    // Try Twitch Embed API video player first
                    if (window.twitchPlayer && typeof window.twitchPlayer.setMuted === 'function') {
                        console.log('🔊 Using Twitch video player setMuted');
                        window.twitchPlayer.setMuted(muted);
                        if (!muted && typeof window.twitchPlayer.setVolume === 'function') {
                            window.twitchPlayer.setVolume(0.7); // Set reasonable volume when unmuting
                        }
                        return;
                    }
                    
                    // Try Twitch Embed instance
                    if (window.twitchEmbedPlayer && typeof window.twitchEmbedPlayer.getPlayer === 'function') {
                        console.log('🔊 Using Twitch embed player setMuted');
                        var videoPlayer = window.twitchEmbedPlayer.getPlayer();
                        if (videoPlayer && typeof videoPlayer.setMuted === 'function') {
                            videoPlayer.setMuted(muted);
                            if (!muted && typeof videoPlayer.setVolume === 'function') {
                                videoPlayer.setVolume(0.7);
                            }
                            return;
                        }
                    }
                    
                    // IMPORTANT: DO NOT reload iframe for mute changes
                    // For iframe players, we can't control mute without reloading,
                    // so we'll accept that limitation to avoid stream interruption
                    console.log('🔊 Iframe player detected - mute control limited to avoid reload');
                };
                
                // Start trying methods
                setTimeout(tryNextMethod, 100);
                
            </script>
        </body>
        </html>
        """
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: TwitchStreamPlayer
        
        init(_ parent: TwitchStreamPlayer) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("TwitchStreamPlayer finished loading")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("TwitchStreamPlayer navigation failed: \(error)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("TwitchStreamPlayer provisional navigation failed: \(error)")
        }
    }
}

struct ContentViewStream {
    let id = UUID()
    let title: String
    let streamerName: String
    let category: String
    let viewerCount: Int
    let thumbnailUrl: String
    let platform: String
    
    static let sampleStreams = [
        ContentViewStream(title: "Just Chatting with the Community", streamerName: "Ninja", category: "Just Chatting", viewerCount: 45000, thumbnailUrl: "https://picsum.photos/320/180?random=1", platform: "twitch"),
        ContentViewStream(title: "Valorant Ranked Grind", streamerName: "Pokimane", category: "Valorant", viewerCount: 32000, thumbnailUrl: "https://picsum.photos/320/180?random=2", platform: "twitch"),
        ContentViewStream(title: "Minecraft Build Battle", streamerName: "xQc", category: "Minecraft", viewerCount: 28000, thumbnailUrl: "https://picsum.photos/320/180?random=3", platform: "twitch"),
        ContentViewStream(title: "Speedrun Practice", streamerName: "Shroud", category: "Super Mario 64", viewerCount: 15000, thumbnailUrl: "https://picsum.photos/320/180?random=4", platform: "twitch"),
        ContentViewStream(title: "Art Stream - Digital Painting", streamerName: "DisguisedToast", category: "Art", viewerCount: 12000, thumbnailUrl: "https://picsum.photos/320/180?random=5", platform: "twitch"),
        ContentViewStream(title: "League of Legends Coaching", streamerName: "Amouranth", category: "League of Legends", viewerCount: 8000, thumbnailUrl: "https://picsum.photos/320/180?random=6", platform: "twitch")
    ]
}

struct StreamSlot {
    var stream: ContentViewStream?
    var twitchStream: TwitchStream?
    var isActive: Bool = false
    var volume: Double = 1.0
    
    var hasStream: Bool {
        return stream != nil || twitchStream != nil
    }
    
    var displayTitle: String {
        return twitchStream?.title ?? stream?.title ?? ""
    }
    
    var displayStreamer: String {
        return twitchStream?.userName ?? stream?.streamerName ?? ""
    }
    
    var displayViewerCount: Int {
        return twitchStream?.viewerCount ?? stream?.viewerCount ?? 0
    }
    
    var displayThumbnail: String {
        return twitchStream?.thumbnailUrlMedium ?? stream?.thumbnailUrl ?? ""
    }
    
    init(stream: ContentViewStream? = nil, twitchStream: TwitchStream? = nil, isActive: Bool = false, volume: Double = 1.0) {
        self.stream = stream
        self.twitchStream = twitchStream
        self.isActive = isActive
        self.volume = volume
    }
}

struct TwitchStreamCard: View {
    let stream: TwitchStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: stream.thumbnailUrlMedium)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "tv")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .frame(height: 100)
            .cornerRadius(8)
            .clipped()
            
            // Stream Info
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(stream.userName)
                    .font(.caption)
                    .foregroundColor(.purple)
                
                HStack {
                    Text(stream.gameName)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text(stream.formattedViewerCount)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct ContentStreamCard: View {
    let stream: ContentViewStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: stream.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "tv")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    )
            }
            .frame(height: 100)
            .cornerRadius(8)
            .clipped()
            
            // Stream Info
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(stream.streamerName)
                    .font(.caption)
                    .foregroundColor(.purple)
                
                HStack {
                    Text(stream.category)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                        Text("\(stream.viewerCount)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct StreamSlotView: View {
    let slot: StreamSlot
    let slotIndex: Int
    let isMuted: Bool
    let onTap: () -> Void
    let onToggleMute: () -> Void
    @State private var showOverlay = true
    
    init(slot: StreamSlot, slotIndex: Int, isMuted: Bool, onTap: @escaping () -> Void, onToggleMute: @escaping () -> Void) {
        self.slot = slot
        self.slotIndex = slotIndex
        self.isMuted = isMuted
        self.onTap = onTap
        self.onToggleMute = onToggleMute
    }
    
    var body: some View {
        ZStack {
            if slot.hasStream {
                // Active stream slot with video playback
                ZStack {
                    // Video player
                    if let twitchStream = slot.twitchStream {
                        TwitchStreamPlayer(
                            channelName: twitchStream.userLogin,
                            isMuted: Binding(
                                get: { isMuted },
                                set: { _ in onToggleMute() }
                            )
                        )
                        .clipped()
                    } else if let stream = slot.stream {
                        // Fallback to thumbnail for non-Twitch streams
                        AsyncImage(url: URL(string: stream.thumbnailUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                                )
                        }
                        .clipped()
                    }
                    
                    // Tap gesture overlay (transparent)
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showOverlay.toggle()
                            }
                        }
                    
                    // Stream info overlay (shows/hides on tap)
                    if showOverlay {
                        VStack {
                            // Live indicator
                            HStack {
                                // Live indicator
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 6, height: 6)
                                    Text("LIVE")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                                
                                // Audio indicator (only show when this stream has audio)
                                if !isMuted {
                                    HStack(spacing: 4) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text("AUDIO")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.8))
                                    .cornerRadius(4)
                                }
                                
                                Spacer()
                                
                                // Controls
                                HStack(spacing: 8) {
                                    Button {
                                        onToggleMute()
                                    } label: {
                                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                            .font(.caption)
                                            .foregroundColor(isMuted ? .red : .green)
                                            .frame(width: 24, height: 24)
                                            .background(isMuted ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                                            .clipShape(Circle())
                                    }
                                    
                                    Button {
                                        // Fullscreen action - will be implemented
                                    } label: {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Color.black.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                    
                                    Button {
                                        onTap()
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .frame(width: 24, height: 24)
                                            .background(Color.black.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Bottom info
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(slot.displayStreamer)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text("\(slot.displayViewerCount) viewers")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        .padding(8)
                        .transition(.opacity)
                    }
                }
            } else {
                // Empty slot
                Button(action: onTap) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 8]))
                        )
                        .overlay(
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "plus")
                                            .font(.system(size: 32, weight: .medium))
                                            .foregroundColor(.purple)
                                    )
                                
                                VStack(spacing: 4) {
                                    Text("Add Stream")
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    Text("Tap to browse streams")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(slot.isActive ? Color.cyan : Color.clear, lineWidth: 2)
        )
        .onAppear {
            // Auto-hide overlay after 3 seconds
            if slot.hasStream {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showOverlay = false
                    }
                }
            }
        }
    }
}

struct LayoutButton: View {
    let layout: MultiStreamTabView.LayoutType
    let current: MultiStreamTabView.LayoutType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(layout == current ? .cyan : .white.opacity(0.6))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(layout == current ? .cyan.opacity(0.2) : .clear)
                )
        }
    }
    
    private var iconName: String {
        switch layout {
        case .single: return "square"
        case .grid2x2: return "rectangle.split.2x2"
        case .grid3x3: return "rectangle.split.3x3"
        case .pip: return "pip"
        }
    }
}

struct StreamPickerView: View {
    @Binding var selectedSlot: Int
    @Binding var streamSlots: [StreamSlot]
    @Environment(\.dismiss) private var dismiss
    @StateObject private var twitchService = RealTwitchAPIService.shared
    @State private var availableStreams: [TwitchStream] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    if isLoading {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            Text("Loading streams...")
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(availableStreams, id: \.id) { stream in
                                Button {
                                    if selectedSlot < streamSlots.count {
                                        streamSlots[selectedSlot] = StreamSlot(twitchStream: stream, isActive: true)
                                    }
                                    dismiss()
                                } label: {
                                    TwitchStreamCard(stream: stream)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Choose Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .onAppear {
                loadStreams()
            }
        }
    }
    
    private func loadStreams() {
        isLoading = true
        Task {
            let result = await twitchService.getTopStreams(first: 40)
            await MainActor.run {
                availableStreams = result.streams
                isLoading = false
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.cyan)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

struct AuthenticationSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Sign In")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Connect your streaming accounts to sync favorites and viewing history")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 12) {
                        Button("Continue with Twitch") {
                            // TODO: Implement Twitch OAuth
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        
                        Button("Continue with Google") {
                            // TODO: Implement Google OAuth
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        
                        Button("Continue with Apple") {
                            // TODO: Implement Apple Sign In
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    Section("Playback") {
                        SettingsRow(title: "Auto-play streams", value: "On")
                        SettingsRow(title: "Default quality", value: "Auto")
                        SettingsRow(title: "Chat enabled", value: "On")
                    }
                    
                    Section("Notifications") {
                        SettingsRow(title: "Stream notifications", value: "On")
                        SettingsRow(title: "Favorite streamers", value: "On")
                    }
                    
                    Section("About") {
                        SettingsRow(title: "Version", value: "1.0.0")
                        SettingsRow(title: "Terms of Service", value: "")
                        SettingsRow(title: "Privacy Policy", value: "")
                    }
                }
                .background(Color.clear)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .foregroundColor(.white.opacity(0.6))
        }
        .listRowBackground(Color.clear)
    }
}

#Preview {
    ContentView()
}