//
//  AdvancedAudioMixingConsoleView.swift
//  StreamyyyApp
//
//  Professional Audio Mixing Console UI
//  Features: Multi-channel mixing, EQ controls, effects, visualization, spatial audio
//

import SwiftUI
import AVFoundation

struct AdvancedAudioMixingConsoleView: View {
    @StateObject private var audioEngine = AdvancedAudioMixingEngine()
    @StateObject private var spatialAudioManager = SpatialAudioManager()
    @StateObject private var visualizationEngine = AudioVisualizationEngine()
    @StateObject private var vadEngine = VoiceActivityDetectionEngine()
    
    @State private var selectedChannelIndex: Int = 0
    @State private var showSpatialControls: Bool = false
    @State private var showVisualization: Bool = true
    @State private var showVADControls: Bool = false
    @State private var showEffectsPanel: Bool = false
    @State private var showPresetPanel: Bool = false
    @State private var consoleMode: ConsoleMode = .mixing
    
    private let channels = ["Stream 1", "Stream 2", "Stream 3", "Stream 4", "Stream 5", "Stream 6"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with mode controls
                headerView
                
                // Main mixing console
                ScrollView {
                    VStack(spacing: 20) {
                        // Audio visualization
                        if showVisualization {
                            audioVisualizationSection
                        }
                        
                        // Master controls
                        masterControlsSection
                        
                        // Channel strips
                        channelStripsSection
                        
                        // Effects and processing
                        if showEffectsPanel {
                            effectsSection
                        }
                        
                        // Spatial audio controls
                        if showSpatialControls {
                            spatialAudioSection
                        }
                        
                        // VAD controls
                        if showVADControls {
                            vadControlsSection
                        }
                        
                        // Preset management
                        if showPresetPanel {
                            presetSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Audio Mixing Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mixing Mode") { consoleMode = .mixing }
                        Button("Spatial Audio") { consoleMode = .spatial }
                        Button("Voice Detection") { consoleMode = .vad }
                        Button("Effects") { consoleMode = .effects }
                        Button("Presets") { consoleMode = .presets }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            // Mode selector
            HStack {
                ForEach(ConsoleMode.allCases, id: \.self) { mode in
                    Button(action: {
                        consoleMode = mode
                        updateViewsForMode(mode)
                    }) {
                        VStack {
                            Image(systemName: mode.icon)
                                .font(.system(size: 18))
                            Text(mode.title)
                                .font(.caption)
                        }
                        .foregroundColor(consoleMode == mode ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Rectangle()
                                .fill(consoleMode == mode ? .blue : .clear)
                                .cornerRadius(8)
                        )
                    }
                }
            }
            .padding(.horizontal)
            
            // Status indicators
            HStack {
                StatusIndicator(
                    title: "Processing",
                    value: audioEngine.isProcessing ? "Active" : "Idle",
                    color: audioEngine.isProcessing ? .green : .orange
                )
                
                StatusIndicator(
                    title: "Channels",
                    value: "\(audioEngine.audioChannels.count)",
                    color: .blue
                )
                
                StatusIndicator(
                    title: "Spatial",
                    value: spatialAudioManager.spatialAudioEnabled ? "On" : "Off",
                    color: spatialAudioManager.spatialAudioEnabled ? .green : .gray
                )
                
                StatusIndicator(
                    title: "VAD",
                    value: vadEngine.isVADEnabled ? "Active" : "Off",
                    color: vadEngine.isVADEnabled ? .green : .gray
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Audio Visualization Section
    private var audioVisualizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Audio Visualization", icon: "waveform")
            
            HStack {
                // Spectrum analyzer
                VStack(alignment: .leading) {
                    Text("Spectrum")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    SpectrumVisualizerView(
                        spectrumData: visualizationEngine.spectrumData,
                        height: 100
                    )
                }
                
                Spacer()
                
                // Audio level meters
                VStack(alignment: .leading) {
                    Text("Levels")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(Array(visualizationEngine.audioLevels.keys.sorted()), id: \.self) { streamId in
                            if let levelData = visualizationEngine.audioLevels[streamId] {
                                AudioLevelMeter(
                                    level: levelData.rms,
                                    peak: levelData.peak,
                                    width: 20,
                                    height: 100
                                )
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Master Controls Section
    private var masterControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Master Controls", icon: "slider.horizontal.3")
            
            VStack(spacing: 20) {
                // Master volume
                VStack(alignment: .leading) {
                    HStack {
                        Text("Master Volume")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(audioEngine.masterVolume * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $audioEngine.masterVolume, in: 0...1) {
                        Text("Master Volume")
                    }
                    .accentColor(.blue)
                }
                
                // Master EQ
                VStack(alignment: .leading) {
                    Text("Master EQ")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        ForEach(0..<10, id: \.self) { band in
                            VStack {
                                Text("\(getEQBandFrequency(band))Hz")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Slider(
                                    value: Binding(
                                        get: { audioEngine.getMasterEQ(band: band) },
                                        set: { audioEngine.setMasterEQ(band: band, gain: $0) }
                                    ),
                                    in: -12...12,
                                    step: 0.1
                                ) {
                                    Text("Band \(band)")
                                }
                                .rotationEffect(.degrees(-90))
                                .frame(width: 30, height: 80)
                                
                                Text("\(Int(audioEngine.getMasterEQ(band: band)))dB")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Master controls toggles
                HStack {
                    Toggle("Mute", isOn: $audioEngine.masterMuted)
                        .toggleStyle(SwitchToggleStyle(tint: .red))
                    
                    Spacer()
                    
                    Toggle("Limiter", isOn: $audioEngine.limiterEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .orange))
                    
                    Spacer()
                    
                    Toggle("Spatial Audio", isOn: $spatialAudioManager.spatialAudioEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Channel Strips Section
    private var channelStripsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Channel Strips", icon: "rectangle.3.group")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(audioEngine.audioChannels.enumerated()), id: \.offset) { index, channel in
                        ChannelStripView(
                            channel: channel,
                            isSelected: selectedChannelIndex == index,
                            onSelect: { selectedChannelIndex = index }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Effects Section
    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Effects & Processing", icon: "waveform.path")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                EffectControlView(
                    title: "Reverb",
                    value: $spatialAudioManager.roomReverbLevel,
                    range: 0...1,
                    icon: "speaker.wave.3"
                )
                
                EffectControlView(
                    title: "Delay",
                    value: Binding(
                        get: { 0.5 }, // Placeholder
                        set: { _ in }
                    ),
                    range: 0...1,
                    icon: "arrow.clockwise"
                )
                
                EffectControlView(
                    title: "Noise Reduction",
                    value: Binding(
                        get: { 0.7 }, // Placeholder
                        set: { _ in }
                    ),
                    range: 0...1,
                    icon: "mic.slash"
                )
                
                EffectControlView(
                    title: "Compressor",
                    value: Binding(
                        get: { 0.3 }, // Placeholder
                        set: { _ in }
                    ),
                    range: 0...1,
                    icon: "waveform.path.ecg"
                )
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Spatial Audio Section
    private var spatialAudioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Spatial Audio", icon: "cube.transparent")
            
            VStack(spacing: 20) {
                // Spatial audio controls
                HStack {
                    Toggle("Head Tracking", isOn: $spatialAudioManager.headTrackingEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    Spacer()
                    
                    Toggle("Room Simulation", isOn: $spatialAudioManager.roomSimulationEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                // Room type selector
                VStack(alignment: .leading) {
                    Text("Room Type")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Room Type", selection: $spatialAudioManager.currentRoom) {
                        ForEach(RoomType.allCases, id: \.self) { room in
                            Text(room.displayName).tag(room)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Spatial positioning
                VStack(alignment: .leading) {
                    Text("Listener Position")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        VStack {
                            Text("X")
                                .font(.caption)
                            Slider(
                                value: Binding(
                                    get: { spatialAudioManager.listenerPosition.x },
                                    set: { newValue in
                                        var pos = spatialAudioManager.listenerPosition
                                        pos.x = newValue
                                        spatialAudioManager.updateListenerPosition(pos)
                                    }
                                ),
                                in: -10...10
                            )
                        }
                        
                        VStack {
                            Text("Y")
                                .font(.caption)
                            Slider(
                                value: Binding(
                                    get: { spatialAudioManager.listenerPosition.y },
                                    set: { newValue in
                                        var pos = spatialAudioManager.listenerPosition
                                        pos.y = newValue
                                        spatialAudioManager.updateListenerPosition(pos)
                                    }
                                ),
                                in: -10...10
                            )
                        }
                        
                        VStack {
                            Text("Z")
                                .font(.caption)
                            Slider(
                                value: Binding(
                                    get: { spatialAudioManager.listenerPosition.z },
                                    set: { newValue in
                                        var pos = spatialAudioManager.listenerPosition
                                        pos.z = newValue
                                        spatialAudioManager.updateListenerPosition(pos)
                                    }
                                ),
                                in: -10...10
                            )
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - VAD Controls Section
    private var vadControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Voice Activity Detection", icon: "mic.badge.plus")
            
            VStack(spacing: 20) {
                // VAD settings
                HStack {
                    Toggle("Auto Switch", isOn: $vadEngine.autoSwitchEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    Spacer()
                    
                    Toggle("Speaker ID", isOn: $vadEngine.speakerIdentificationEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                
                // Voice activity threshold
                VStack(alignment: .leading) {
                    HStack {
                        Text("Voice Activity Threshold")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(vadEngine.voiceActivityThreshold * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $vadEngine.voiceActivityThreshold, in: 0...1)
                        .accentColor(.blue)
                }
                
                // Current speaking stream
                if let speakingStream = vadEngine.currentSpeakingStream {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.green)
                        Text("Currently Speaking: \(speakingStream)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                
                // Voice activity indicators
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(Array(vadEngine.voiceActivities.keys.sorted()), id: \.self) { streamId in
                        if let activity = vadEngine.voiceActivities[streamId] {
                            VoiceActivityIndicator(
                                streamId: streamId,
                                activity: activity,
                                confidence: vadEngine.confidenceScores[streamId] ?? 0.0
                            )
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Preset Section
    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Presets", icon: "doc.text")
            
            VStack(spacing: 16) {
                // Preset selector
                HStack {
                    Menu {
                        Button("Default") {
                            audioEngine.applyPreset(.default)
                        }
                        Button("Live Performance") {
                            // Apply live performance preset
                        }
                        Button("Podcast") {
                            // Apply podcast preset
                        }
                        Button("Music") {
                            // Apply music preset
                        }
                    } label: {
                        HStack {
                            Text("Current Preset: \(audioEngine.currentPreset.name)")
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // Preset actions
                HStack {
                    Button("Save Current") {
                        let preset = audioEngine.saveCurrentAsPreset(name: "Custom \(Date())")
                        // Save preset
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Button("Reset to Default") {
                        audioEngine.applyPreset(.default)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper Methods
    private func updateViewsForMode(_ mode: ConsoleMode) {
        showVisualization = mode == .mixing || mode == .effects
        showSpatialControls = mode == .spatial
        showVADControls = mode == .vad
        showEffectsPanel = mode == .effects
        showPresetPanel = mode == .presets
    }
    
    private func getEQBandFrequency(_ band: Int) -> Int {
        let frequencies = [60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000]
        return frequencies[band]
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ChannelStripView: View {
    let channel: AudioChannel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Channel header
            VStack(spacing: 4) {
                Text(channel.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Circle()
                    .fill(channel.muted ? .red : .green)
                    .frame(width: 8, height: 8)
            }
            
            // EQ controls
            HStack(spacing: 8) {
                EQKnob(
                    value: $channel.trebleGain,
                    range: -12...12,
                    label: "Hi"
                )
                EQKnob(
                    value: $channel.midGain,
                    range: -12...12,
                    label: "Mid"
                )
                EQKnob(
                    value: $channel.bassGain,
                    range: -12...12,
                    label: "Lo"
                )
            }
            
            // Volume fader
            VStack {
                Slider(
                    value: $channel.volume,
                    in: 0...1
                ) {
                    Text("Volume")
                }
                .rotationEffect(.degrees(-90))
                .frame(width: 30, height: 100)
                
                Text("\(Int(channel.volume * 100))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Pan control
            VStack(spacing: 4) {
                Text("Pan")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: $channel.pan,
                    in: -1...1
                )
                .frame(width: 60)
            }
            
            // Mute and Solo
            HStack {
                Button(action: {
                    channel.setMuted(!channel.muted)
                }) {
                    Text("M")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(channel.muted ? .white : .primary)
                        .frame(width: 20, height: 20)
                        .background(channel.muted ? .red : .clear)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.red, lineWidth: 1)
                        )
                }
                
                Button(action: {
                    channel.setSolo(!channel.solo)
                }) {
                    Text("S")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(channel.solo ? .white : .primary)
                        .frame(width: 20, height: 20)
                        .background(channel.solo ? .yellow : .clear)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.yellow, lineWidth: 1)
                        )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? .blue.opacity(0.1) : .ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? .blue : .clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            onSelect()
        }
    }
}

struct EQKnob: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.secondary, lineWidth: 2)
                    .frame(width: 30, height: 30)
                
                Circle()
                    .trim(from: 0, to: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))
                    .stroke(.blue, lineWidth: 3)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .fill(.blue)
                    .frame(width: 4, height: 4)
                    .offset(y: -11)
                    .rotationEffect(.degrees(Double((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * 270 - 135))
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let angle = atan2(gesture.location.y - 15, gesture.location.x - 15)
                        let normalizedAngle = (angle + .pi / 2) / (1.5 * .pi)
                        let newValue = range.lowerBound + Float(normalizedAngle) * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, newValue))
                    }
            )
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct EffectControlView: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range)
                .accentColor(.blue)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct VoiceActivityIndicator: View {
    let streamId: String
    let activity: VoiceActivity
    let confidence: Float
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(activity.isActive ? .green : .gray)
                    .frame(width: 8, height: 8)
                
                Text(streamId)
                    .font(.caption)
                    .lineLimit(1)
                
                Spacer()
            }
            
            HStack {
                Text("Confidence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(confidence * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: confidence)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 0.5)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct SpectrumVisualizerView: View {
    let spectrumData: [Float]
    let height: CGFloat
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 1) {
            ForEach(0..<min(spectrumData.count, 64), id: \.self) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(
                        width: 3,
                        height: max(1, CGFloat(abs(spectrumData[index])) * height / 60)
                    )
                    .animation(.easeInOut(duration: 0.1), value: spectrumData[index])
            }
        }
        .frame(height: height)
    }
}

struct AudioLevelMeter: View {
    let level: Float
    let peak: Float
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            // Peak indicator
            Rectangle()
                .fill(.red)
                .frame(width: width, height: 2)
                .offset(y: CGFloat(1.0 - peak) * height)
            
            // Level meter
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.red, .yellow, .green],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: CGFloat(level) * height)
                .animation(.easeInOut(duration: 0.1), value: level)
        }
        .frame(width: width, height: height)
        .background(.black.opacity(0.3))
        .cornerRadius(2)
    }
}

// MARK: - Console Mode Enum
enum ConsoleMode: String, CaseIterable {
    case mixing = "mixing"
    case spatial = "spatial"
    case vad = "vad"
    case effects = "effects"
    case presets = "presets"
    
    var title: String {
        switch self {
        case .mixing: return "Mixing"
        case .spatial: return "Spatial"
        case .vad: return "Voice"
        case .effects: return "Effects"
        case .presets: return "Presets"
        }
    }
    
    var icon: String {
        switch self {
        case .mixing: return "slider.horizontal.3"
        case .spatial: return "cube.transparent"
        case .vad: return "mic.badge.plus"
        case .effects: return "waveform.path"
        case .presets: return "doc.text"
        }
    }
}

#Preview {
    AdvancedAudioMixingConsoleView()
}