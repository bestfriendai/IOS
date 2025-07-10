//
//  ContentView.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var streamManager: StreamManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @State private var showSplash = true
    @State private var selectedTab = 0
    
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
            } else if authManager.isAuthenticated {
                MainTabView(selectedTab: $selectedTab)
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut, value: showSplash)
        .animation(.easeInOut, value: authManager.isAuthenticated)
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

// MARK: - Main Tab View
struct MainTabView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var streamManager: StreamManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Streams Tab
            StreamsView()
                .tabItem {
                    Image(systemName: "play.tv")
                    Text("Streams")
                }
                .tag(0)
            
            // Discover Tab
            DiscoverView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Discover")
                }
                .tag(1)
            
            // Favorites Tab
            FavoritesView()
                .tabItem {
                    Image(systemName: "heart")
                    Text("Favorites")
                }
                .tag(2)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("Profile")
                }
                .tag(3)
        }
        .accentColor(.purple)
    }
}

// MARK: - Authentication View
struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Logo Section
                    VStack(spacing: 16) {
                        Image(systemName: "play.tv")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.purple)
                        
                        Text("Streamyyy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Watch multiple streams simultaneously")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Form Section
                    VStack(spacing: 20) {
                        VStack(spacing: 16) {
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if isSignUp {
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        // Error Message
                        if let errorMessage = authManager.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        // Action Button
                        Button(action: handleAuthentication) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(isSignUp ? "Sign Up" : "Sign In")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(authManager.isLoading || !isFormValid)
                        
                        // Toggle Button
                        Button(action: {
                            withAnimation {
                                isSignUp.toggle()
                                clearForm()
                            }
                        }) {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .foregroundColor(.purple)
                                .font(.footnote)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && (!isSignUp || password == confirmPassword)
    }
    
    private func handleAuthentication() {
        Task {
            if isSignUp {
                await authManager.signUp(email: email, password: password)
            } else {
                await authManager.signIn(email: email, password: password)
            }
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        authManager.errorMessage = nil
    }
}

// MARK: - Streams View
struct StreamsView: View {
    @EnvironmentObject var streamManager: StreamManager
    @State private var showingAddStream = false
    @State private var newStreamURL = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if streamManager.streams.isEmpty {
                    EmptyStreamsView(showingAddStream: $showingAddStream)
                } else {
                    StreamGridView()
                }
            }
            .navigationTitle("Streams")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Add Stream", action: { showingAddStream = true })
                        Button("Clear All", role: .destructive, action: streamManager.clearAllStreams)
                        
                        Menu("Layout") {
                            ForEach(StreamManager.LayoutType.allCases, id: \.self) { layout in
                                Button(action: { streamManager.selectedLayout = layout }) {
                                    Label(layout.rawValue, systemImage: layout.icon)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddStream) {
                AddStreamView()
            }
        }
    }
}

// MARK: - Empty Streams View
struct EmptyStreamsView: View {
    @Binding var showingAddStream: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.tv")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Streams Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first stream to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Add Stream") {
                showingAddStream = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

// MARK: - Stream Grid View
struct StreamGridView: View {
    @EnvironmentObject var streamManager: StreamManager
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(streamManager.streams) { stream in
                    StreamCardView(stream: stream)
                }
            }
            .padding()
        }
    }
    
    private var gridColumns: [GridItem] {
        switch streamManager.selectedLayout {
        case .stack:
            return [GridItem(.flexible())]
        case .grid2x2:
            return Array(repeating: GridItem(.flexible()), count: 2)
        case .grid3x3:
            return Array(repeating: GridItem(.flexible()), count: 3)
        case .carousel, .focus:
            return [GridItem(.flexible())]
        }
    }
}

// MARK: - Stream Card View
struct StreamCardView: View {
    let stream: StreamModel
    @EnvironmentObject var streamManager: StreamManager
    @State private var showingFullScreen = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Stream Preview
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                
                // Placeholder for actual stream content
                VStack {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Live Stream")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                
                // Controls Overlay
                VStack {
                    HStack {
                        // Live indicator
                        if stream.isLive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 6, height: 6)
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        // Remove button
                        Button(action: { streamManager.removeStream(stream) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        // Mute button
                        Button(action: {}) {
                            Image(systemName: stream.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        // Fullscreen button
                        Button(action: { showingFullScreen = true }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(8)
            }
            .cornerRadius(12)
            .onTapGesture {
                showingFullScreen = true
            }
            
            // Stream Info
            VStack(alignment: .leading, spacing: 4) {
                Text(stream.title)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    // Stream type badge
                    Text(stream.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(stream.type.color)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    if stream.isLive {
                        Text("\(stream.viewerCount) viewers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .fullScreenCover(isPresented: $showingFullScreen) {
            FullScreenStreamView(stream: stream)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(StreamManager())
        .environmentObject(SubscriptionManager())
}