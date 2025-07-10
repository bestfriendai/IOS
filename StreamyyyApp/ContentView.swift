//
//  ContentView.swift
//  StreamyyyApp
//
//  Simple entry point for the app
//

import SwiftUI
import SafariServices
import WebKit

// MARK: - Modern Main View (Integrated)
struct ModernMainView: View {
    @StateObject private var streamStore = StreamStoreManager()
    @State private var selectedTab = 0
    @State private var selectedStream: TwitchStream?
    @State private var showingStreamPlayer = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Discover Tab
            DiscoverTab(
                streamStore: streamStore,
                onStreamSelected: { stream in
                    selectedStream = stream
                    showingStreamPlayer = true
                }
            )
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Discover")
            }
            .tag(0)
            
            // Browse Tab
            BrowseTab(
                streamStore: streamStore,
                onStreamSelected: { stream in
                    selectedStream = stream
                    showingStreamPlayer = true
                }
            )
            .tabItem {
                Image(systemName: "rectangle.grid.2x2")
                Text("Browse")
            }
            .tag(1)
            
            // Profile Tab
            ProfileTab()
            .tabItem {
                Image(systemName: "person")
                Text("Profile")
            }
            .tag(2)
        }
        .accentColor(.purple)
        .sheet(isPresented: $showingStreamPlayer) {
            if let stream = selectedStream {
                ModernStreamPlayerSheet(stream: stream, isPresented: $showingStreamPlayer)
            }
        }
        .onAppear {
            Task {
                await streamStore.loadStreams()
            }
        }
    }
}

// MARK: - Modern Stream Player Sheet
struct ModernStreamPlayerSheet: View {
    let stream: TwitchStream
    @Binding var isPresented: Bool
    @State private var showingSafari = false
    @State private var addedToMultiStream = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Stream Preview
                VStack(alignment: .leading, spacing: 12) {
                    AsyncImage(url: URL(string: stream.thumbnailUrl.replacingOccurrences(of: "{width}", with: "640").replacingOccurrences(of: "{height}", with: "360"))) { image in
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(
                                Image(systemName: "tv")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        VStack {
                            HStack {
                                Spacer()
                                Text("LIVE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .cornerRadius(6)
                            }
                            Spacer()
                        }
                        .padding(12)
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stream.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(2)
                        
                        HStack {
                            Text(stream.userName)
                                .font(.headline)
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            Text("\(stream.formattedViewerCount) viewers")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if !stream.gameName.isEmpty {
                            Text("Playing: \(stream.gameName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Watch Options
                VStack(spacing: 16) {
                    Button(action: {
                        showingSafari = true
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Watch in Browser")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        addToMultiStream()
                    }) {
                        HStack {
                            Image(systemName: addedToMultiStream ? "checkmark.circle.fill" : "plus.rectangle.on.rectangle")
                            Text(addedToMultiStream ? "Added to Multi-Stream" : "Add to Multi-Stream")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(addedToMultiStream ? Color.green : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(addedToMultiStream)
                    
                    Button(action: {
                        openInTwitchApp()
                    }) {
                        HStack {
                            Image(systemName: "tv")
                            Text("Open Twitch App")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Watch Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingSafari) {
            SafariView(url: URL(string: "https://m.twitch.tv/\(stream.userLogin)")!)
        }
    }
    
    private func addToMultiStream() {
        // For now, we'll show a visual confirmation
        // In a real app, this would notify the multi-stream manager
        withAnimation(.easeInOut(duration: 0.3)) {
            addedToMultiStream = true
        }
        
        // Post notification to add stream to multi-stream view
        NotificationCenter.default.post(
            name: Notification.Name("AddStreamToMultiView"),
            object: stream
        )
        
        // Auto-dismiss after confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isPresented = false
        }
    }
    
    private func openInTwitchApp() {
        if let twitchURL = URL(string: "twitch://stream/\(stream.userLogin)"),
           UIApplication.shared.canOpenURL(twitchURL) {
            UIApplication.shared.open(twitchURL)
            isPresented = false
        } else {
            if let appStoreURL = URL(string: "https://apps.apple.com/app/twitch/id460177396") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = UIColor.systemPurple
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Discover Tab
struct DiscoverTab: View {
    @ObservedObject var streamStore: StreamStoreManager
    let onStreamSelected: (TwitchStream) -> Void
    @State private var searchText = ""
    
    var filteredStreams: [TwitchStream] {
        if searchText.isEmpty {
            return streamStore.streams
        } else {
            return streamStore.streams.filter { stream in
                stream.title.localizedCaseInsensitiveContains(searchText) ||
                stream.userName.localizedCaseInsensitiveContains(searchText) ||
                stream.gameName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search streams...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let errorMessage = streamStore.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Try Again") {
                                streamStore.clearError()
                                streamStore.refreshStreams()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 50)
                    }
                    // Streams Grid
                    else if streamStore.isLoading {
                        ProgressView("Loading streams...")
                            .padding(.top, 50)
                    } else if filteredStreams.isEmpty {
                        VStack {
                            Image(systemName: "tv.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No streams found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 50)
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(filteredStreams) { stream in
                                ModernStreamCard(stream: stream, onTap: {
                                    onStreamSelected(stream)
                                })
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Discover")
            .refreshable {
                await streamStore.loadStreams()
            }
            .onAppear {
                streamStore.startAutoRefresh()
            }
            .onDisappear {
                streamStore.stopAutoRefresh()
            }
        }
    }
}

// MARK: - Browse Tab
struct BrowseTab: View {
    @ObservedObject var streamStore: StreamStoreManager
    let onStreamSelected: (TwitchStream) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !streamStore.topStreams.isEmpty {
                        StreamSection(
                            title: "Top Streams",
                            streams: streamStore.topStreams,
                            onStreamSelected: onStreamSelected
                        )
                    }
                    
                    if !streamStore.gamingStreams.isEmpty {
                        StreamSection(
                            title: "Gaming",
                            streams: streamStore.gamingStreams,
                            onStreamSelected: onStreamSelected
                        )
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Browse")
            .refreshable {
                await streamStore.loadStreams()
            }
        }
    }
}

// MARK: - Profile Tab
struct ProfileTab: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
                
                VStack(spacing: 8) {
                    Text("Guest User")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Sign in to personalize your experience")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    Button("Sign In") {
                        // TODO: Implement
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Settings") {
                        // TODO: Implement
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Supporting Views
struct StreamSection: View {
    let title: String
    let streams: [TwitchStream]
    let onStreamSelected: (TwitchStream) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(streams.prefix(6)) { stream in
                    ModernStreamCard(stream: stream, onTap: {
                        onStreamSelected(stream)
                    })
                }
            }
            .padding(.horizontal)
        }
    }
}

struct ModernStreamCard: View {
    let stream: TwitchStream
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: URL(string: stream.thumbnailUrl.replacingOccurrences(of: "{width}", with: "320").replacingOccurrences(of: "{height}", with: "180"))) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(ProgressView())
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    VStack {
                        HStack {
                            Spacer()
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Text(stream.formattedViewerCount)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                    }
                    .padding(8)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(stream.userName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.purple)
                    
                    if !stream.gameName.isEmpty {
                        Text(stream.gameName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .foregroundColor(.primary)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stream Store Manager
@MainActor
class StreamStoreManager: ObservableObject {
    @Published var streams: [TwitchStream] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var lastRefreshTime: Date?
    private let refreshInterval: TimeInterval = 30 // 30 seconds minimum between refreshes
    private var refreshTimer: Timer?
    
    var topStreams: [TwitchStream] {
        Array(streams.sorted { $0.viewerCount > $1.viewerCount }.prefix(6))
    }
    
    var gamingStreams: [TwitchStream] {
        Array(streams.filter { !$0.gameName.isEmpty && $0.gameName.lowercased() != "just chatting" }.prefix(6))
    }
    
    init() {
        // Initialize with some test data while API loads
        Task {
            await loadStreams()
        }
    }
    
    func loadStreams() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let twitchService = await RealTwitchAPIService.shared
            await twitchService.validateAndRefreshTokens()
            let (fetchedStreams, _) = await twitchService.getTopStreams(first: 50)
            
            streams = fetchedStreams
            isLoading = false
            lastRefreshTime = Date()
            
            if fetchedStreams.isEmpty {
                errorMessage = "No streams available"
            }
        } catch {
            isLoading = false
            errorMessage = "Failed to load streams: \(error.localizedDescription)"
            print("❌ Failed to load streams: \(error)")
            
            // Fallback to mock data for testing
            loadMockStreams()
        }
    }
    
    private func loadMockStreams() {
        streams = [
            TwitchStream(
                id: "mock1",
                userId: "user1",
                userLogin: "gamesdonequick",
                userName: "Games Done Quick",
                gameId: "33214",
                gameName: "Variety",
                type: "live",
                title: "Awesome Games Done Quick 2025",
                viewerCount: 45000,
                startedAt: "2025-01-10T12:00:00Z",
                language: "en",
                thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_gamesdonequick-{width}x{height}.jpg",
                tagIds: [],
                isMature: false
            ),
            TwitchStream(
                id: "mock2",
                userId: "user2",
                userLogin: "esl_csgo",
                userName: "ESL CS:GO",
                gameId: "32399",
                gameName: "Counter-Strike 2",
                type: "live",
                title: "ESL Pro League",
                viewerCount: 32000,
                startedAt: "2025-01-10T11:30:00Z",
                language: "en",
                thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_esl_csgo-{width}x{height}.jpg",
                tagIds: [],
                isMature: false
            ),
            TwitchStream(
                id: "mock3",
                userId: "user3",
                userLogin: "riotgames",
                userName: "Riot Games",
                gameId: "21779",
                gameName: "League of Legends",
                type: "live",
                title: "LCS Championship",
                viewerCount: 28000,
                startedAt: "2025-01-10T10:45:00Z",
                language: "en",
                thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_riotgames-{width}x{height}.jpg",
                tagIds: [],
                isMature: false
            ),
            TwitchStream(
                id: "mock4",
                userId: "user4",
                userLogin: "monstercat",
                userName: "Monstercat",
                gameId: "26936",
                gameName: "Music",
                type: "live",
                title: "24/7 Music Stream",
                viewerCount: 15000,
                startedAt: "2025-01-10T10:00:00Z",
                language: "en",
                thumbnailUrl: "https://static-cdn.jtvnw.net/previews-ttv/live_user_monstercat-{width}x{height}.jpg",
                tagIds: [],
                isMature: false
            )
        ]
    }
    
    func refreshStreams() {
        // Prevent too frequent refreshes
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < refreshInterval {
            return
        }
        
        Task {
            await loadStreams()
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                self.refreshStreams()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        Task { @MainActor in
            stopAutoRefresh()
        }
    }
}

// MARK: - Working Multi Stream View
struct MultiStreamView: View {
    @StateObject private var streamStore = StreamStoreManager()
    @State private var selectedStreams: [TwitchStream?] = [nil, nil, nil, nil]
    @State private var currentLayout: GridLayout = .twoByTwo
    @State private var showingStreamPicker = false
    @State private var selectedSlotIndex = 0
    @State private var showingFocusView = false
    @State private var focusedStreamIndex: Int?
    @State private var showingAddStreamPopup = false
    
    enum GridLayout: String, CaseIterable {
        case single = "Single"
        case twoByTwo = "2×2"
        case threeByThree = "3×3"
        
        var columns: Int {
            switch self {
            case .single: return 1
            case .twoByTwo: return 2
            case .threeByThree: return 3
            }
        }
        
        var maxStreams: Int {
            switch self {
            case .single: return 1
            case .twoByTwo: return 4
            case .threeByThree: return 9
            }
        }
        
        var icon: String {
            switch self {
            case .single: return "square"
            case .twoByTwo: return "grid"
            case .threeByThree: return "square.grid.3x3"
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
                        Menu {
                            ForEach(GridLayout.allCases, id: \.self) { layout in
                                Button(action: {
                                    updateLayout(layout)
                                }) {
                                    HStack {
                                        Image(systemName: layout.icon)
                                        Text(layout.rawValue)
                                        if layout == currentLayout {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: currentLayout.icon)
                                Text(currentLayout.rawValue)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Text("\(selectedStreams.compactMap { $0 }.count)/\(currentLayout.maxStreams)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Multi-Stream Grid
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: currentLayout.columns), spacing: 4) {
                            ForEach(0..<currentLayout.maxStreams, id: \.self) { index in
                                StreamSlot(
                                    stream: index < selectedStreams.count ? selectedStreams[index] : nil,
                                    index: index,
                                    isCompact: currentLayout != .single,
                                    onTap: {
                                        if selectedStreams[safe: index] == nil {
                                            selectedSlotIndex = index
                                            showingStreamPicker = true
                                        }
                                    },
                                    onLongPress: {
                                        if selectedStreams[safe: index] != nil {
                                            focusedStreamIndex = index
                                            showingFocusView = true
                                        }
                                    },
                                    onRemove: {
                                        removeStream(at: index)
                                    }
                                )
                                .aspectRatio(16/9, contentMode: .fill)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    
                    // Quick Actions
                    HStack(spacing: 16) {
                        Button(action: {
                            if let emptyIndex = selectedStreams.firstIndex(where: { $0 == nil }) {
                                selectedSlotIndex = emptyIndex
                                showingStreamPicker = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add Stream")
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple)
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Button("Clear All") {
                            clearAllStreams()
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Multi-Stream")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingStreamPicker) {
            StreamPickerSheet(
                streamStore: streamStore,
                selectedSlotIndex: selectedSlotIndex,
                onStreamSelected: { stream in
                    addStream(stream, to: selectedSlotIndex)
                    showingStreamPicker = false
                }
            )
        }
        .fullScreenCover(isPresented: $showingFocusView) {
            if let focusIndex = focusedStreamIndex,
               let stream = selectedStreams[safe: focusIndex],
               let unwrappedStream = stream {
                FocusedStreamView(
                    stream: unwrappedStream,
                    onDismiss: {
                        showingFocusView = false
                        focusedStreamIndex = nil
                    }
                )
            }
        }
        .onAppear {
            Task {
                await streamStore.loadStreams()
            }
            updateLayout(currentLayout)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AddStreamToMultiView"))) { notification in
            if let stream = notification.object as? TwitchStream {
                addStreamFromNotification(stream)
            }
        }
    }
    
    private func updateLayout(_ layout: GridLayout) {
        currentLayout = layout
        let newSize = layout.maxStreams
        
        if selectedStreams.count < newSize {
            selectedStreams.append(contentsOf: Array(repeating: nil, count: newSize - selectedStreams.count))
        } else if selectedStreams.count > newSize {
            selectedStreams = Array(selectedStreams.prefix(newSize))
        }
    }
    
    private func addStream(_ stream: TwitchStream, to index: Int) {
        if index < selectedStreams.count {
            selectedStreams[index] = stream
        }
    }
    
    private func removeStream(at index: Int) {
        if index < selectedStreams.count {
            selectedStreams[index] = nil
        }
    }
    
    private func clearAllStreams() {
        selectedStreams = Array(repeating: nil, count: currentLayout.maxStreams)
    }
    
    private func addStreamFromNotification(_ stream: TwitchStream) {
        // Find the first empty slot
        if let emptyIndex = selectedStreams.firstIndex(where: { $0 == nil }) {
            selectedStreams[emptyIndex] = stream
            
            // Show a brief confirmation
            let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
            hapticFeedback.impactOccurred()
        }
    }
}

// MARK: - Stream Slot
struct StreamSlot: View {
    let stream: TwitchStream?
    let index: Int
    let isCompact: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onRemove: () -> Void
    
    @State private var showControls = false
    
    var body: some View {
        ZStack {
            Color.black
            
            if let stream = stream {
                // Simple Twitch stream player
                SimpleCompactPlayer(stream: stream)
                
                // Remove button overlay for compact view
                if showControls {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: onRemove) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }
            } else {
                // Empty Slot
                Button(action: onTap) {
                    VStack(spacing: isCompact ? 4 : 12) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: isCompact ? 20 : 40))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if !isCompact {
                            Text("Add Stream")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            if stream != nil && isCompact {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showControls.toggle()
                }
                
                // Auto-hide controls after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls = false
                    }
                }
            } else if stream == nil {
                onTap()
            }
        }
        .onLongPressGesture {
            if stream != nil {
                onLongPress()
            }
        }
    }
}

// MARK: - Stream Picker Sheet
struct StreamPickerSheet: View {
    @ObservedObject var streamStore: StreamStoreManager
    let selectedSlotIndex: Int
    let onStreamSelected: (TwitchStream) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredStreams: [TwitchStream] {
        if searchText.isEmpty {
            return streamStore.streams
        } else {
            return streamStore.streams.filter { stream in
                stream.title.localizedCaseInsensitiveContains(searchText) ||
                stream.userName.localizedCaseInsensitiveContains(searchText) ||
                stream.gameName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                searchBarView
                streamContentView
            }
            .navigationTitle("Add to Slot \(selectedSlotIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search streams...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var streamContentView: some View {
        Group {
            if let errorMessage = streamStore.errorMessage {
                errorStateView(message: errorMessage)
            } else if streamStore.isLoading {
                loadingView
            } else if filteredStreams.isEmpty {
                emptyStateView
            } else {
                streamListView
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Loading streams...")
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            VStack {
                Image(systemName: "tv.slash")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("No streams found")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private var streamListView: some View {
        ScrollView {
            LazyVStack {
                ForEach(filteredStreams) { stream in
                    StreamRowButton(stream: stream, onTap: {
                        onStreamSelected(stream)
                    })
                }
            }
        }
    }
    
    private func errorStateView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error Loading Streams")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                streamStore.clearError()
                streamStore.refreshStreams()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
    }
}

// MARK: - Stream Row Button
struct StreamRowButton: View {
    let stream: TwitchStream
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                streamThumbnail
                streamInfo
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .foregroundColor(.primary)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var streamThumbnail: some View {
        AsyncImage(url: URL(string: stream.thumbnailUrl.replacingOccurrences(of: "{width}", with: "160").replacingOccurrences(of: "{height}", with: "90"))) { image in
            image
                .resizable()
                .aspectRatio(16/9, contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fill)
        }
        .frame(width: 80, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var streamInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stream.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Text(stream.userName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
            
            streamMetadata
        }
    }
    
    private var streamMetadata: some View {
        HStack {
            Text(stream.formattedViewerCount)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if !stream.gameName.isEmpty {
                Text("• \(stream.gameName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Focused Stream View
struct FocusedStreamView: View {
    let stream: TwitchStream
    let onDismiss: () -> Void
    
    var body: some View {
        FullscreenTwitchPlayerView(stream: stream, onDismiss: onDismiss)
    }
}

// MARK: - Extensions
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Multi Stream Main View (Core Feature First)
struct MultiStreamMainView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Multi-Stream Tab - THE MAIN FEATURE
            MultiStreamView()
            .tabItem {
                Image(systemName: "rectangle.3.group.fill")
                Text("Multi-Stream")
            }
            .tag(0)
            
            // Discover Tab - For finding streams to add
            ModernMainView()
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Discover")
            }
            .tag(1)
            
            // Profile Tab
            ProfileTab()
            .tabItem {
                Image(systemName: "person")
                Text("Profile")
            }
            .tag(2)
        }
        .accentColor(.purple)
    }
}

struct ContentView: View {
    @State private var showSplash = true
    
    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                MultiStreamMainView()
            }
        }
        .animation(.easeInOut, value: showSplash)
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Streamyyy Logo
                Image(systemName: "play.tv")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Text("Streamyyy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(logoOpacity)
                
                Text("Multi-Stream Viewer")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}


// MARK: - Main App View
struct MainAppView: View {
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationView {
                VStack(spacing: 30) {
                    // Welcome Section
                    VStack(spacing: 16) {
                        Image(systemName: "tv.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        
                        Text("Welcome to Streamyyy!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Your Multi-Stream Dashboard")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Quick Actions
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        DashboardCard(
                            title: "Multi-Stream",
                            subtitle: "Watch multiple streams",
                            icon: "rectangle.3.group.fill",
                            color: .blue
                        )
                        
                        DashboardCard(
                            title: "Discover",
                            subtitle: "Find popular streams",
                            icon: "magnifyingglass.circle.fill",
                            color: .green
                        )
                        
                        DashboardCard(
                            title: "Favorites",
                            subtitle: "Your saved streams",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        DashboardCard(
                            title: "Settings",
                            subtitle: "Configure your app",
                            icon: "gear.circle.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)
            
            // Streams Tab - Multi-Stream View
            NavigationView {
                VStack {
                    Text("Multi-Stream View")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Multi-stream functionality will be available here")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Streams")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "rectangle.3.group.fill")
                Text("Streams")
            }
            .tag(1)
            
            // Discover Tab - Live Streams
            LiveStreamsView()
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Discover")
            }
            .tag(2)
            
            // Favorites Tab
            NavigationView {
                VStack {
                    Text("Favorites")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your favorite streams will appear here")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Favorites")
                .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Image(systemName: "heart.fill")
                Text("Favorites")
            }
            .tag(3)
        }
    }
}

// MARK: - Dashboard Card
struct DashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Audio Manager
@MainActor
class MultiStreamAudioManager: ObservableObject {
    static let shared = MultiStreamAudioManager()
    
    @Published var activeAudioStreamId: String? = nil
    
    private init() {}
    
    func setActiveAudioStream(_ streamId: String) {
        if activeAudioStreamId == streamId {
            // If tapping the same stream, mute it
            activeAudioStreamId = nil
        } else {
            // Set new active stream
            activeAudioStreamId = streamId
        }
        
        // Post notification for all streams to update their audio state
        NotificationCenter.default.post(
            name: Notification.Name("AudioStreamChanged"),
            object: activeAudioStreamId
        )
    }
    
    func isStreamAudioActive(_ streamId: String) -> Bool {
        return activeAudioStreamId == streamId
    }
    
    func muteAll() {
        activeAudioStreamId = nil
        NotificationCenter.default.post(
            name: Notification.Name("AudioStreamChanged"),
            object: nil
        )
    }
}

// MARK: - Auto-Play Twitch Player
struct AutoPlayTwitchPlayer: UIViewRepresentable {
    let stream: TwitchStream
    let isAudioActive: Bool
    let onLoadComplete: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        
        let shouldMute = !isAudioActive
        let twitchURL = "https://player.twitch.tv/?channel=\(stream.userLogin)&parent=localhost&muted=\(shouldMute)&autoplay=true&controls=false"
        
        // Load the stream with current audio state
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { 
                    width: 100%; 
                    height: 100%; 
                    background: #000; 
                    overflow: hidden;
                }
                iframe { 
                    width: 100%; 
                    height: 100%; 
                    border: none;
                }
            </style>
        </head>
        <body>
            <iframe 
                id="twitchPlayer"
                src="\(twitchURL)"
                frameborder="0" 
                allowfullscreen="true" 
                scrolling="no">
            </iframe>
            <script>
                console.log("Loading Twitch stream: \(stream.userLogin), muted: \(shouldMute)");
                
                // Listen for audio state changes
                window.addEventListener('message', function(event) {
                    if (event.data.type === 'updateAudio') {
                        const iframe = document.getElementById('twitchPlayer');
                        const newSrc = event.data.muted ? 
                            "\(twitchURL.replacingOccurrences(of: "muted=\(shouldMute)", with: "muted=true"))" :
                            "\(twitchURL.replacingOccurrences(of: "muted=\(shouldMute)", with: "muted=false"))";
                        iframe.src = newSrc;
                    }
                });
                
                // Signal that the stream has loaded
                setTimeout(function() {
                    window.webkit.messageHandlers.streamLoaded.postMessage('loaded');
                }, 2000);
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: URL(string: "https://player.twitch.tv"))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: AutoPlayTwitchPlayer
        
        init(_ parent: AutoPlayTwitchPlayer) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ Stream loaded: \(parent.stream.userLogin)")
            parent.onLoadComplete()
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ Stream failed: \(error.localizedDescription)")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "streamLoaded" {
                parent.onLoadComplete()
            }
        }
    }
}

// MARK: - Simple Twitch Player Components

struct SimpleTwitchPlayer: UIViewRepresentable {
    let channelName: String
    let isCompact: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Use Twitch's mobile-optimized embed
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { 
                    width: 100%; 
                    height: 100%; 
                    background: #000; 
                    overflow: hidden;
                }
                #twitch-embed { 
                    width: 100%; 
                    height: 100%; 
                }
            </style>
        </head>
        <body>
            <div id="twitch-embed"></div>
            <script src="https://embed.twitch.tv/embed/v1.js"></script>
            <script>
                try {
                    new Twitch.Embed("twitch-embed", {
                        width: "100%",
                        height: "100%",
                        channel: "\(channelName)",
                        layout: "video-with-chat",
                        autoplay: true,
                        muted: \(isCompact ? "true" : "false"),
                        controls: true,
                        allowfullscreen: true,
                        parent: ["localhost", "127.0.0.1", "player.twitch.tv"]
                    });
                    console.log("Twitch embed loaded for: \(channelName)");
                } catch (error) {
                    console.error("Failed to load Twitch embed:", error);
                    // Fallback to direct iframe
                    document.getElementById("twitch-embed").innerHTML = 
                        '<iframe src="https://player.twitch.tv/?channel=\(channelName)&parent=localhost&muted=\(isCompact ? "true" : "false")&autoplay=true" width="100%" height="100%" frameborder="0" allowfullscreen></iframe>';
                }
            </script>
        </body>
        </html>
        """
        
        print("🎥 Loading Twitch channel: \(channelName)")
        webView.loadHTMLString(html, baseURL: URL(string: "https://player.twitch.tv"))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView provisional load failed: \(error.localizedDescription)")
        }
    }
}

struct SimpleCompactPlayer: View {
    let stream: TwitchStream
    @State private var showingFullscreen = false
    @State private var useDirectURL = true  // Start with direct URL for better reliability
    @StateObject private var audioManager = MultiStreamAudioManager.shared
    @State private var isStreamLoaded = false
    
    var body: some View {
        ZStack {
            Color.black
            
            // Auto-playing Twitch stream with audio management
            AutoPlayTwitchPlayer(
                stream: stream,
                isAudioActive: audioManager.isStreamAudioActive(stream.id),
                onLoadComplete: {
                    isStreamLoaded = true
                }
            )
            
            // Stream controls overlay
            VStack {
                HStack {
                    Text(stream.userName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    // Audio toggle button
                    Button(action: {
                        audioManager.setActiveAudioStream(stream.id)
                    }) {
                        Image(systemName: audioManager.isStreamAudioActive(stream.id) ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.caption)
                            .foregroundColor(audioManager.isStreamAudioActive(stream.id) ? .green : .white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                    
                    // Fullscreen button
                    Button(action: {
                        showingFullscreen = true
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Circle())
                    }
                }
                .padding(8)
                
                Spacer()
                
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                        
                        Text(stream.formattedViewerCount)
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(3)
                    
                    Spacer()
                    
                    // Audio indicator
                    if audioManager.isStreamAudioActive(stream.id) {
                        HStack(spacing: 2) {
                            ForEach(0..<3) { i in
                                Rectangle()
                                    .fill(Color.green)
                                    .frame(width: 2, height: CGFloat.random(in: 4...12))
                                    .animation(.easeInOut(duration: 0.5).repeatForever(), value: UUID())
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(3)
                    }
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingFullscreen) {
            NavigationView {
                ZStack {
                    Color.black
                    WebView(url: URL(string: "https://www.twitch.tv/\(stream.userLogin)")!)
                }
                .navigationTitle(stream.userName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingFullscreen = false
                        }
                    }
                }
            }
        }
    }
}

// Simple WebView for direct URL loading
struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// MARK: - Advanced Twitch Player Components

struct TwitchEmbedPlayerView: UIViewRepresentable {
    let stream: TwitchStream
    let isCompact: Bool
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = false
        
        // Add user content controller for message handling
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "loadingHandler")
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = UIColor.black
        webView.isOpaque = true
        webView.allowsBackForwardNavigationGestures = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Use direct Twitch player URL instead of embed API
        let twitchURL = "https://player.twitch.tv/?channel=\(stream.userLogin)&parent=localhost&autoplay=\(isCompact ? "false" : "true")&muted=\(isCompact ? "true" : "false")"
        
        print("🎥 Loading Twitch stream: \(twitchURL)")
        
        if let url = URL(string: twitchURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        } else {
            print("❌ Invalid Twitch URL: \(twitchURL)")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: TwitchEmbedPlayerView
        
        init(_ parent: TwitchEmbedPlayerView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed to load: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "loadingHandler" {
                DispatchQueue.main.async {
                    self.parent.isLoading = false
                }
            }
        }
    }
}

struct CompactTwitchPlayerView: View {
    let stream: TwitchStream
    @State private var isLoading = true
    @State private var showingFullscreen = false
    @State private var loadFailed = false
    
    var body: some View {
        ZStack {
            Color.black
            
            if loadFailed {
                // Fallback to show thumbnail with play button
                AsyncImage(url: URL(string: stream.thumbnailUrl.replacingOccurrences(of: "{width}", with: "320").replacingOccurrences(of: "{height}", with: "180"))) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                }
                .overlay(
                    Button(action: {
                        showingFullscreen = true
                    }) {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            )
                    }
                )
            } else {
                TwitchEmbedPlayerView(
                    stream: stream,
                    isCompact: true,
                    isLoading: $isLoading
                )
                .onAppear {
                    // Set a timeout to show fallback if loading takes too long
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        if isLoading {
                            loadFailed = true
                            isLoading = false
                        }
                    }
                }
            }
            
            if isLoading && !loadFailed {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading \(stream.userName)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // Overlay controls for compact view
            VStack {
                HStack {
                    Text(stream.userName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    if !loadFailed {
                        Button(action: {
                            showingFullscreen = true
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(8)
                
                Spacer()
                
                HStack {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                        
                        Text(stream.formattedViewerCount)
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(3)
                    
                    Spacer()
                }
                .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .fullScreenCover(isPresented: $showingFullscreen) {
            FullscreenTwitchPlayerView(stream: stream) {
                showingFullscreen = false
            }
        }
    }
}

struct FullscreenTwitchPlayerView: View {
    let stream: TwitchStream
    let onDismiss: () -> Void
    @State private var isLoading = true
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TwitchEmbedPlayerView(
                stream: stream,
                isCompact: false,
                isLoading: $isLoading
            )
            
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading \(stream.userName)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
            
            // Fullscreen controls
            if showControls && !isLoading {
                VStack {
                    HStack {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stream.title)
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            HStack {
                                Text(stream.userName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.purple)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    
                                    Text("LIVE • \(stream.formattedViewerCount)")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                            
                            if !stream.gameName.isEmpty {
                                Text("Playing: \(stream.gameName)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.8), Color.clear]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
                .transition(.opacity)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls.toggle()
            }
            resetControlsTimer()
        }
        .onAppear {
            resetControlsTimer()
        }
        .onDisappear {
            controlsTimer?.invalidate()
        }
    }
    
    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }
}

#Preview {
    ContentView()
}