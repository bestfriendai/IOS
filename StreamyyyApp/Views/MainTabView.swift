//
//  MainTabView.swift
//  StreamyyyApp
//
//  Main tab navigation view
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingNotifications = false
    @State private var notificationCount = 0
    @StateObject private var tabViewModel = TabViewModel()
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Streams Tab - Enhanced with modern design
                StreamGridView()
                    .tabItem {
                        VStack {
                            Image(systemName: selectedTab == 0 ? "tv.fill" : "tv")
                                .environment(\.symbolVariants, selectedTab == 0 ? .fill : .none)
                            Text("Streams")
                        }
                    }
                    .tag(0)
                
                // Discovery Tab - Enhanced
                DiscoverView()
                    .tabItem {
                        VStack {
                            Image(systemName: selectedTab == 1 ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                                .environment(\.symbolVariants, selectedTab == 1 ? .fill : .none)
                            Text("Discover")
                        }
                    }
                    .tag(1)
                
                // MultiStream Tab - Main multi-stream viewer
                MultiStreamView()
                    .tabItem {
                        VStack {
                            Image(systemName: selectedTab == 2 ? "rectangle.3.group.fill" : "rectangle.3.group")
                                .environment(\.symbolVariants, selectedTab == 2 ? .fill : .none)
                            Text("MultiStream")
                        }
                    }
                    .tag(2)
                
                // Favorites Tab - Enhanced (for saved multistreams)
                ModernFavoritesView()
                    .tabItem {
                        VStack {
                            Image(systemName: selectedTab == 3 ? "heart.fill" : "heart")
                                .environment(\.symbolVariants, selectedTab == 3 ? .fill : .none)
                            Text("Saved")
                        }
                    }
                    .tag(3)
                    .badge(tabViewModel.favoritesBadgeCount)
                
                // Profile Tab - Enhanced
                ModernProfileView()
                    .tabItem {
                        VStack {
                            Image(systemName: selectedTab == 4 ? "person.fill" : "person")
                                .environment(\.symbolVariants, selectedTab == 4 ? .fill : .none)
                            Text("Profile")
                        }
                    }
                    .tag(4)
                    .badge(tabViewModel.settingsBadgeCount)
            }
            .tint(.cyan)
        }
        .onAppear {
            setupModernTabBar()
        }
        .onChange(of: selectedTab) { newValue in
            tabViewModel.tabChanged(to: newValue)
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func setupModernTabBar() {
        // Modern tab bar appearance with glassmorphism
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Background with blur effect
        appearance.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        
        // Selected item appearance with gradient colors
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemCyan
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemCyan,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        
        // Normal item appearance
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.6)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.6),
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]
        
        // Badge appearance
        appearance.stackedLayoutAppearance.selected.badgeBackgroundColor = UIColor.systemRed
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = UIColor.systemRed
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Add subtle border
        UITabBar.appearance().layer.borderWidth = 0.5
        UITabBar.appearance().layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
    }
}

// MARK: - Tab View Model
@MainActor
class TabViewModel: ObservableObject {
    @Published var favoritesBadgeCount = 0
    @Published var settingsBadgeCount = 0
    
    init() {
        loadBadgeCounts()
    }
    
    func tabChanged(to index: Int) {
        // Handle tab selection
        switch index {
        case 0:
            // Streams tab selected
            break
        case 1:
            // Discovery tab selected
            break
        case 2:
            // Favorites tab selected
            favoritesBadgeCount = 0
        case 3:
            // Profile tab selected
            break
        case 4:
            // Settings tab selected
            settingsBadgeCount = 0
        default:
            break
        }
    }
    
    private func loadBadgeCounts() {
        // Load badge counts from various sources
        // This would typically fetch from Core Data, UserDefaults, or API
        
        // Example: Load favorites count
        // favoritesBadgeCount = FavoritesManager.shared.newFavoritesCount
        
        // Example: Load settings notifications
        // settingsBadgeCount = SettingsManager.shared.pendingUpdatesCount
    }
}

// MARK: - Tab Bar Custom Views
struct CustomTabBarView: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    
    var body: some View {
        HStack {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == index,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = index
                        }
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            BlurView(style: .systemMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .purple : .gray)
                
                Text(tab.title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .purple : .gray)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TabItem {
    let title: String
    let icon: String
    let selectedIcon: String
    let badgeCount: Int
    
    init(title: String, icon: String, selectedIcon: String, badgeCount: Int = 0) {
        self.title = title
        self.icon = icon
        self.selectedIcon = selectedIcon
        self.badgeCount = badgeCount
    }
}

// MARK: - Blur View
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Tab Navigation Extensions
extension MainTabView {
    enum Tab: Int, CaseIterable {
        case streams = 0
        case discovery = 1
        case favorites = 2
        case profile = 3
        case settings = 4
        
        var title: String {
            switch self {
            case .streams: return "Streams"
            case .discovery: return "Discover"
            case .favorites: return "Favorites"
            case .profile: return "Profile"
            case .settings: return "Settings"
            }
        }
        
        var icon: String {
            switch self {
            case .streams: return "tv"
            case .discovery: return "magnifyingglass.circle"
            case .favorites: return "heart"
            case .profile: return "person"
            case .settings: return "gear"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .streams: return "tv.fill"
            case .discovery: return "magnifyingglass.circle.fill"
            case .favorites: return "heart.fill"
            case .profile: return "person.fill"
            case .settings: return "gear.badge.fill"
            }
        }
    }
}

// MARK: - Tab Navigation Helper
class TabNavigationHelper: ObservableObject {
    @Published var selectedTab = 0
    
    func navigateToTab(_ tab: MainTabView.Tab) {
        selectedTab = tab.rawValue
    }
    
    func navigateToStreams() {
        selectedTab = MainTabView.Tab.streams.rawValue
    }
    
    func navigateToDiscovery() {
        selectedTab = MainTabView.Tab.discovery.rawValue
    }
    
    func navigateToFavorites() {
        selectedTab = MainTabView.Tab.favorites.rawValue
    }
    
    func navigateToProfile() {
        selectedTab = MainTabView.Tab.profile.rawValue
    }
    
    func navigateToSettings() {
        selectedTab = MainTabView.Tab.settings.rawValue
    }
}

// MARK: - Adaptive Tab View
struct AdaptiveTabView: View {
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .regular && verticalSizeClass == .regular {
            // iPad layout
            NavigationView {
                SidebarView(selectedTab: $selectedTab)
                    .navigationTitle("Streamyyy")
                
                contentView
            }
            .navigationViewStyle(DoubleColumnNavigationViewStyle())
        } else {
            // iPhone layout
            MainTabView()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case 0:
            StreamGridView()
        case 1:
            DiscoveryView()
        case 2:
            FavoritesView()
        case 3:
            ProfileView()
        case 4:
            SettingsView()
        default:
            StreamGridView()
        }
    }
}

// MARK: - Sidebar View (iPad)
struct SidebarView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        List {
            Section("Browse") {
                SidebarItem(
                    title: "Streams",
                    icon: "tv",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                SidebarItem(
                    title: "Discover",
                    icon: "magnifyingglass.circle",
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
                
                SidebarItem(
                    title: "Favorites",
                    icon: "heart",
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                }
            }
            
            Section("Account") {
                SidebarItem(
                    title: "Profile",
                    icon: "person",
                    isSelected: selectedTab == 3
                ) {
                    selectedTab = 3
                }
                
                SidebarItem(
                    title: "Settings",
                    icon: "gear",
                    isSelected: selectedTab == 4
                ) {
                    selectedTab = 4
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
}

struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .purple : .primary)
                    .frame(width: 25)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(isSelected ? .purple : .primary)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.purple.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                QuickActionButton(
                    title: "Add Stream",
                    icon: "plus",
                    color: .purple
                ) {
                    // Add stream action
                }
                
                QuickActionButton(
                    title: "Go Live",
                    icon: "video",
                    color: .red
                ) {
                    // Go live action
                }
                
                QuickActionButton(
                    title: "Browse",
                    icon: "safari",
                    color: .blue
                ) {
                    selectedTab = 1
                }
                
                QuickActionButton(
                    title: "Settings",
                    icon: "gear",
                    color: .gray
                ) {
                    selectedTab = 4
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Tab Views

struct ModernStreamGridView: View {
    var body: some View {
        NavigationView {
            StreamGridView()
        }
    }
}

struct ModernDiscoveryView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.purple.opacity(0.1),
                    Color.cyan.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("🔍 Discover")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .cyan.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Find new streams and streamers")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                // Modern search bar placeholder
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Search streams, games, or streamers...")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
}

struct ModernFavoritesView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.orange.opacity(0.1),
                    Color.yellow.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("🔖 Saved")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Your saved multistream layouts")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    ForEach(0..<4) { index in
                        HStack {
                            // Preview of the multistream layout
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .frame(width: 80, height: 50)
                                .overlay(
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 1) {
                                        ForEach(0..<4) { _ in
                                            Rectangle()
                                                .fill(Color.cyan.opacity(0.3))
                                                .frame(height: 10)
                                        }
                                    }
                                    .padding(4)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("2x2 Gaming Layout")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("\(Int.random(in: 2...4)) streams • Saved \(Int.random(in: 1...7)) days ago")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "play.fill")
                                    .font(.title3)
                                    .foregroundColor(.cyan)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(.ultraThinMaterial))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
}

struct ModernProfileView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.blue.opacity(0.1),
                    Color.cyan.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Profile avatar
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.cyan)
                }
                
                VStack(spacing: 8) {
                    Text("Demo User")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("streamyyy@demo.com")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Settings options
                VStack(spacing: 12) {
                    SettingsRow(icon: "gear", title: "Settings", color: .cyan)
                    SettingsRow(icon: "bell", title: "Notifications", color: .orange)
                    SettingsRow(icon: "questionmark.circle", title: "Help & Support", color: .blue)
                    SettingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign Out", color: .red)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .padding(.top, 40)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MainTabView()
}