//
//  ModernMainTabView.swift
//  StreamyyyApp
//
//  Enhanced main navigation with simplified 4-tab structure and modern design
//

import SwiftUI

struct ModernMainTabView: View {
    @StateObject private var appState = AppStateManager.shared
    @State private var tabBarOffset: CGFloat = 0
    @State private var previousSelectedTab: MainTab = .discover
    
    enum MainTab: Int, CaseIterable, Identifiable {
        case discover = 0
        case watch = 1
        case library = 2
        case profile = 3
        
        var id: Int { rawValue }
        
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
        
        var color: Color {
            switch self {
            case .discover: return .cyan
            case .watch: return .purple
            case .library: return .orange
            case .profile: return .green
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Tab content
            TabView(selection: $appState.selectedTab) {
                // Discover Tab
                EnhancedDiscoverView()
                    .tag(MainTab.discover)
                    .tabItem { EmptyView() }
                
                // Watch Tab (Multi-Stream)
                ModernMultiStreamView()
                    .tag(MainTab.watch)
                    .tabItem { EmptyView() }
                
                // Library Tab
                EnhancedLibraryView()
                    .tag(MainTab.library)
                    .tabItem { EmptyView() }
                
                // Profile Tab
                EnhancedProfileView()
                    .tag(MainTab.profile)
                    .tabItem { EmptyView() }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: appState.selectedTab)
            
            // Custom floating tab bar
            VStack {
                Spacer()
                customTabBar
                    .offset(y: tabBarOffset)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: appState.selectedTab) { newTab in
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            previousSelectedTab = newTab
        }
        .withAppState()
    }
    
    // MARK: - Custom Tab Bar
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                tabBarItem(for: tab)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            // Glassmorphism background
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 8)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func tabBarItem(for tab: MainTab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.selectedTab = tab
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // Background indicator
                    if appState.selectedTab == tab {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tab.color, tab.color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .scaleEffect(appState.selectedTab == tab ? 1.0 : 0.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.selectedTab)
                    }
                    
                    // Icon
                    Image(systemName: appState.selectedTab == tab ? tab.selectedIcon : tab.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(appState.selectedTab == tab ? .white : .white.opacity(0.6))
                        .scaleEffect(appState.selectedTab == tab ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.selectedTab)
                }
                
                // Title
                Text(tab.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(appState.selectedTab == tab ? tab.color : .white.opacity(0.6))
                    .scaleEffect(appState.selectedTab == tab ? 1.0 : 0.9)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.selectedTab)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(TabBarButtonStyle())
    }
}

// MARK: - Tab Bar Button Style
struct TabBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Enhanced Discover View
struct EnhancedDiscoverView: View {
    @State private var searchText = ""
    @State private var selectedCategory: StreamCategory = .all
    @State private var showingFilters = false
    @State private var featuredStreams: [TwitchStream] = []
    @State private var trendingStreams: [TwitchStream] = []
    
    enum StreamCategory: String, CaseIterable {
        case all = "All"
        case gaming = "Gaming"
        case justChatting = "Just Chatting"
        case music = "Music"
        case sports = "Sports"
        case creative = "Creative"
        
        var icon: String {
            switch self {
            case .all: return "globe"
            case .gaming: return "gamecontroller"
            case .justChatting: return "bubble.left.and.bubble.right"
            case .music: return "music.note"
            case .sports: return "sportscourt"
            case .creative: return "paintbrush"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Search header
                        searchHeader
                        
                        // Category filters
                        categoryFilters
                        
                        // Featured streams
                        featuredSection
                        
                        // Trending streams
                        trendingSection
                        
                        // Quick actions
                        quickActionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadMockData()
        }
    }
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Find amazing live streams")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: { showingFilters.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(ModernButtonStyle())
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.6))
                
                TextField("Search streams, streamers, games...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Category Filters
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StreamCategory.allCases, id: \.self) { category in
                    categoryButton(category: category)
                }
            }
            .padding(.horizontal, 1)
        }
    }
    
    private func categoryButton(category: StreamCategory) -> some View {
        Button(action: { selectedCategory = category }) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(selectedCategory == category ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(selectedCategory == category ? Color.cyan : .ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(selectedCategory == category ? 0 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
    
    // MARK: - Featured Section
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Featured")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {
                    // Navigate to full featured list
                }
                .font(.subheadline)
                .foregroundColor(.cyan)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(featuredStreams.prefix(5), id: \.id) { stream in
                        FeaturedStreamCard(stream: stream)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
    
    // MARK: - Trending Section
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trending Now")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("See All") {
                    // Navigate to full trending list
                }
                .font(.subheadline)
                .foregroundColor(.cyan)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(trendingStreams.prefix(6), id: \.id) { stream in
                    TrendingStreamRow(stream: stream)
                }
            }
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                quickActionCard(
                    title: "Add Stream",
                    description: "Paste a stream URL",
                    icon: "plus.circle",
                    color: .purple
                ) {
                    // Show add stream dialog
                }
                
                quickActionCard(
                    title: "Start Multi-Stream",
                    description: "Begin watching multiple streams",
                    icon: "rectangle.3.offgrid",
                    color: .cyan
                ) {
                    // Navigate to multi-stream
                }
            }
        }
    }
    
    private func quickActionCard(title: String, description: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ModernButtonStyle())
    }
    
    // MARK: - Helper Methods
    private func loadMockData() {
        // Mock featured streams
        featuredStreams = [
            TwitchStream(id: "f1", userId: "f1", userLogin: "shroud", userName: "Shroud", gameId: "1", gameName: "VALORANT", type: "live", title: "Pro Gameplay", viewerCount: 25000, startedAt: "2025-07-10T10:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_shroud-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
            TwitchStream(id: "f2", userId: "f2", userLogin: "pokimane", userName: "Pokimane", gameId: "2", gameName: "Just Chatting", type: "live", title: "Morning Chat", viewerCount: 18000, startedAt: "2025-07-10T09:30:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_pokimane-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false)
        ]
        
        // Mock trending streams
        trendingStreams = [
            TwitchStream(id: "t1", userId: "t1", userLogin: "xqc", userName: "xQc", gameId: "3", gameName: "GTA V", type: "live", title: "NoPixel RP", viewerCount: 45000, startedAt: "2025-07-10T08:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_xqc-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false),
            TwitchStream(id: "t2", userId: "t2", userLogin: "ninja", userName: "Ninja", gameId: "4", gameName: "Fortnite", type: "live", title: "Arena Practice", viewerCount: 32000, startedAt: "2025-07-10T11:00:00Z", language: "en", thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_ninja-{width}x{height}.jpg", tagIds: nil, tags: nil, isMature: false)
        ]
    }
}

// MARK: - Featured Stream Card
struct FeaturedStreamCard: View {
    let stream: TwitchStream
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: stream.thumbnailUrlLarge)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
            }
            .frame(width: 200, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                VStack {
                    HStack {
                        Spacer()
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                    Spacer()
                }
                .padding(8)
            )
            
            // Stream info
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(stream.userName)
                    .font(.caption2)
                    .foregroundColor(.purple)
                
                Text("\(stream.formattedViewerCount) viewers")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: 200)
    }
}

// MARK: - Trending Stream Row
struct TrendingStreamRow: View {
    let stream: TwitchStream
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: stream.thumbnailUrlMedium)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
            }
            .frame(width: 60, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stream.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(stream.userName)
                    .font(.caption)
                    .foregroundColor(.purple)
                
                Text("\(stream.formattedViewerCount) • \(stream.gameName)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button(action: {
                // Add to multi-stream
            }) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Enhanced Library View
struct EnhancedLibraryView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Text("Enhanced Library View")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Enhanced Profile View
struct EnhancedProfileView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Text("Enhanced Profile View")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    ModernMainTabView()
}