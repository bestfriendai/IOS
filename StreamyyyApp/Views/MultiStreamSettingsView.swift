//
//  MultiStreamSettingsView.swift
//  StreamyyyApp
//
//  Comprehensive settings panel for multi-stream functionality
//

import SwiftUI

struct MultiStreamSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Audio Settings
    @State private var autoSwitchAudio = true
    @State private var crossfadeEnabled = true
    @State private var duckingEnabled = false
    @State private var globalVolume: Double = 0.8
    
    // Layout Settings
    @State private var rememberLayouts = true
    @State private var autoOptimizeLayout = true
    @State private var showStreamInfo = true
    @State private var showViewerCount = true
    
    // Performance Settings
    @State private var limitConcurrentStreams = false
    @State private var maxConcurrentStreams: Double = 4
    @State private var adaptiveQuality = true
    @State private var lowPowerMode = false
    
    // Advanced Settings
    @State private var enableAnalytics = true
    @State private var debugMode = false
    @State private var preloadStreams = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView
                        
                        // Audio Settings
                        audioSettingsSection
                        
                        // Layout Settings
                        layoutSettingsSection
                        
                        // Performance Settings
                        performanceSettingsSection
                        
                        // Advanced Settings
                        advancedSettingsSection
                        
                        // Reset Section
                        resetSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Multi-Stream Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Customize your multi-streaming experience")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .foregroundColor(.cyan)
            .font(.subheadline)
            .fontWeight(.medium)
        }
    }
    
    // MARK: - Audio Settings
    private var audioSettingsSection: some View {
        SettingsSection(
            title: "Audio",
            icon: "speaker.wave.2",
            iconColor: .green
        ) {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Auto-Switch Audio",
                    description: "Automatically switch audio when selecting streams",
                    isOn: $autoSwitchAudio
                )
                
                SettingsToggle(
                    title: "Crossfade",
                    description: "Smooth audio transitions between streams",
                    isOn: $crossfadeEnabled
                )
                
                SettingsToggle(
                    title: "Audio Ducking",
                    description: "Lower other streams when one is focused",
                    isOn: $duckingEnabled
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Global Volume")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(globalVolume * 100))%")
                            .font(.caption)
                            .foregroundColor(.cyan)
                    }
                    
                    Slider(value: $globalVolume, in: 0...1)
                        .tint(.cyan)
                }
            }
        }
    }
    
    // MARK: - Layout Settings
    private var layoutSettingsSection: some View {
        SettingsSection(
            title: "Layout",
            icon: "rectangle.3.offgrid",
            iconColor: .purple
        ) {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Remember Layouts",
                    description: "Save and restore custom stream layouts",
                    isOn: $rememberLayouts
                )
                
                SettingsToggle(
                    title: "Auto-Optimize Layout",
                    description: "Automatically adjust layout based on stream count",
                    isOn: $autoOptimizeLayout
                )
                
                SettingsToggle(
                    title: "Show Stream Info",
                    description: "Display streamer names and game titles",
                    isOn: $showStreamInfo
                )
                
                SettingsToggle(
                    title: "Show Viewer Count",
                    description: "Display live viewer counts on streams",
                    isOn: $showViewerCount
                )
            }
        }
    }
    
    // MARK: - Performance Settings
    private var performanceSettingsSection: some View {
        SettingsSection(
            title: "Performance",
            icon: "speedometer",
            iconColor: .orange
        ) {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Limit Concurrent Streams",
                    description: "Restrict number of simultaneous streams",
                    isOn: $limitConcurrentStreams
                )
                
                if limitConcurrentStreams {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Concurrent Streams")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(Int(maxConcurrentStreams))")
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                        
                        Slider(value: $maxConcurrentStreams, in: 1...16, step: 1)
                            .tint(.cyan)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                SettingsToggle(
                    title: "Adaptive Quality",
                    description: "Automatically adjust quality based on performance",
                    isOn: $adaptiveQuality
                )
                
                SettingsToggle(
                    title: "Low Power Mode",
                    description: "Reduce CPU and battery usage",
                    isOn: $lowPowerMode
                )
            }
        }
    }
    
    // MARK: - Advanced Settings
    private var advancedSettingsSection: some View {
        SettingsSection(
            title: "Advanced",
            icon: "gear",
            iconColor: .cyan
        ) {
            VStack(spacing: 16) {
                SettingsToggle(
                    title: "Analytics",
                    description: "Collect usage data to improve performance",
                    isOn: $enableAnalytics
                )
                
                SettingsToggle(
                    title: "Debug Mode",
                    description: "Show detailed logging and performance metrics",
                    isOn: $debugMode
                )
                
                SettingsToggle(
                    title: "Preload Streams",
                    description: "Load streams in background for faster switching",
                    isOn: $preloadStreams
                )
                
                // Performance Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Performance Info")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Memory Usage")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("~340 MB")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CPU Usage")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("~25%")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bandwidth")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("~8 Mbps")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))
                    )
                }
            }
        }
    }
    
    // MARK: - Reset Section
    private var resetSection: some View {
        VStack(spacing: 16) {
            Button(action: resetToDefaults) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                    
                    Text("Reset to Defaults")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            Text("This will reset all multi-stream settings to their default values")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Methods
    private func resetToDefaults() {
        withAnimation(.easeInOut) {
            // Audio Settings
            autoSwitchAudio = true
            crossfadeEnabled = true
            duckingEnabled = false
            globalVolume = 0.8
            
            // Layout Settings
            rememberLayouts = true
            autoOptimizeLayout = true
            showStreamInfo = true
            showViewerCount = true
            
            // Performance Settings
            limitConcurrentStreams = false
            maxConcurrentStreams = 4
            adaptiveQuality = true
            lowPowerMode = false
            
            // Advanced Settings
            enableAnalytics = true
            debugMode = false
            preloadStreams = false
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
}

// MARK: - Settings Toggle
struct SettingsToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.cyan)
        }
    }
}

#Preview {
    MultiStreamSettingsView()
}