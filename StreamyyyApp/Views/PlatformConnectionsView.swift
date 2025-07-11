//
//  PlatformConnectionsView.swift
//  StreamyyyApp
//
//  Platform connections management (Twitch, YouTube, Kick, etc.)
//

import SwiftUI

struct PlatformConnectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var isConnecting = false
    @State private var selectedPlatform: StreamingPlatform?
    @State private var showingConnectionAlert = false
    @State private var connectionMessage = ""
    @State private var showingDisconnectAlert = false
    @State private var platformToDisconnect: StreamingPlatform?
    
    private let platforms: [StreamingPlatform] = [
        StreamingPlatform(
            name: "Twitch",
            icon: "gamecontroller.fill",
            color: .purple,
            description: "Connect your Twitch account to access your followed channels and chat",
            features: ["Live stream notifications", "Chat integration", "Followed channels", "Stream history"]
        ),
        StreamingPlatform(
            name: "YouTube",
            icon: "play.rectangle.fill",
            color: .red,
            description: "Connect YouTube to access your subscriptions and live streams",
            features: ["Subscription notifications", "Live stream access", "Watch history sync", "Playlist integration"]
        ),
        StreamingPlatform(
            name: "Kick",
            icon: "bolt.fill",
            color: .green,
            description: "Connect Kick for live streaming and community features",
            features: ["Live notifications", "Community access", "Stream discovery", "Chat features"]
        ),
        StreamingPlatform(
            name: "Discord",
            icon: "message.fill",
            color: .indigo,
            description: "Connect Discord for community integration and notifications",
            features: ["Community updates", "Voice chat integration", "Server notifications", "Friend activity"]
        ),
        StreamingPlatform(
            name: "Facebook Gaming",
            icon: "gamecontroller",
            color: .blue,
            description: "Connect Facebook Gaming for live streams and gaming content",
            features: ["Gaming notifications", "Friend streams", "Group integration", "Live alerts"]
        ),
        StreamingPlatform(
            name: "Instagram Live",
            icon: "camera.fill",
            color: .pink,
            description: "Connect Instagram for live video content and stories",
            features: ["Live video access", "Story integration", "IGTV content", "Creator updates"]
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.cyan)
                        
                        Text("Platform Connections")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Connect your streaming platforms to unlock personalized features and stay updated with your favorite content")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                    
                    // Platform Cards
                    LazyVStack(spacing: 16) {
                        ForEach(platforms, id: \.name) { platform in
                            PlatformCard(
                                platform: platform,
                                isConnected: isConnected(platform),
                                isConnecting: isConnecting && selectedPlatform?.name == platform.name,
                                onConnect: {
                                    connectPlatform(platform)
                                },
                                onDisconnect: {
                                    showDisconnectAlert(for: platform)
                                }
                            )
                        }
                    }
                    
                    // Connected Platforms Summary
                    connectedPlatformsSummary
                    
                    // Benefits Section
                    benefitsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(backgroundGradient)
            .navigationTitle("Platform Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Platform Connection", isPresented: $showingConnectionAlert) {
            Button("OK") { }
        } message: {
            Text(connectionMessage)
        }
        .alert("Disconnect Platform", isPresented: $showingDisconnectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disconnect", role: .destructive) {
                if let platform = platformToDisconnect {
                    disconnectPlatform(platform)
                }
            }
        } message: {
            Text("Are you sure you want to disconnect \\(platformToDisconnect?.name ?? "this platform")? You'll lose access to its features and notifications.")
        }
    }
    
    private var backgroundGradient: some View {
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
    }
    
    private var connectedPlatformsSummary: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Connected Platforms")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\\(connectedCount)/\\(platforms.count)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if connectedCount > 0 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(platforms.filter { isConnected($0) }, id: \.name) { platform in
                        VStack(spacing: 8) {
                            Image(systemName: platform.icon)
                                .font(.title2)
                                .foregroundColor(platform.color)
                            
                            Text(platform.name)
                                .font(.caption)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(platform.color.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(platform.color.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("No platforms connected yet")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Connect your first platform to get started")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Why Connect Platforms?")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                BenefitCard(
                    icon: "bell.fill",
                    title: "Live Notifications",
                    description: "Get notified when your favorite streamers go live"
                )
                
                BenefitCard(
                    icon: "heart.fill",
                    title: "Personalized Feed",
                    description: "See content from creators you follow across platforms"
                )
                
                BenefitCard(
                    icon: "message.fill",
                    title: "Unified Chat",
                    description: "Chat across different platforms in one interface"
                )
                
                BenefitCard(
                    icon: "chart.bar.fill",
                    title: "Enhanced Analytics",
                    description: "Get detailed insights about your viewing habits"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    private var connectedCount: Int {
        platforms.filter { isConnected($0) }.count
    }
    
    private func isConnected(_ platform: StreamingPlatform) -> Bool {
        switch platform.name {
        case "Twitch":
            return authService.twitchAuthStatus == .authenticated
        case "YouTube":
            return authService.youtubeAuthStatus == .authenticated
        default:
            // For other platforms, check UserDefaults or other storage
            return UserDefaults.standard.bool(forKey: "\\(platform.name.lowercased())_connected")
        }
    }
    
    private func connectPlatform(_ platform: StreamingPlatform) {
        isConnecting = true
        selectedPlatform = platform
        
        Task {
            do {
                switch platform.name {
                case "Twitch":
                    try await authService.authenticateWithTwitch()
                case "YouTube":
                    try await authService.authenticateWithYouTube()
                default:
                    // Mock connection for other platforms
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    UserDefaults.standard.set(true, forKey: "\\(platform.name.lowercased())_connected")
                }
                
                await MainActor.run {
                    connectionMessage = "\\(platform.name) connected successfully!"
                    showingConnectionAlert = true
                    isConnecting = false
                    selectedPlatform = nil
                }
            } catch {
                await MainActor.run {
                    connectionMessage = "Failed to connect \\(platform.name): \\(error.localizedDescription)"
                    showingConnectionAlert = true
                    isConnecting = false
                    selectedPlatform = nil
                }
            }
        }
    }
    
    private func showDisconnectAlert(for platform: StreamingPlatform) {
        platformToDisconnect = platform
        showingDisconnectAlert = true
    }
    
    private func disconnectPlatform(_ platform: StreamingPlatform) {
        Task {
            switch platform.name {
            case "Twitch", "YouTube":
                await authService.signOut()
            default:
                UserDefaults.standard.set(false, forKey: "\\(platform.name.lowercased())_connected")
            }
            
            await MainActor.run {
                connectionMessage = "\\(platform.name) disconnected successfully"
                showingConnectionAlert = true
                platformToDisconnect = nil
            }
        }
    }
}

// MARK: - Supporting Models and Views

struct StreamingPlatform {
    let name: String
    let icon: String
    let color: Color
    let description: String
    let features: [String]
}

struct PlatformCard: View {
    let platform: StreamingPlatform
    let isConnected: Bool
    let isConnecting: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Platform Icon
                Image(systemName: platform.icon)
                    .font(.system(size: 32))
                    .foregroundColor(platform.color)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(platform.color.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(platform.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(platform.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isConnected {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Text(platform.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            
            // Features
            if !platform.features.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(platform.features, id: \.self) { feature in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(platform.color)
                                
                                Text(feature)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
            
            // Action Button
            Button(action: isConnected ? onDisconnect : onConnect) {
                HStack {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isConnecting ? "Connecting..." : isConnected ? "Disconnect" : "Connect")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isConnected ? Color.red.opacity(0.8) : platform.color)
                )
                .foregroundColor(.white)
            }
            .disabled(isConnecting)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isConnected ? platform.color.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct BenefitCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.cyan)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cyan.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    PlatformConnectionsView()
}"