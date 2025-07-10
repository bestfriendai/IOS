//
//  AudioAccessibilityManager.swift
//  StreamyyyApp
//
//  Audio Accessibility Features for Multi-Stream Applications
//  Features: Audio Descriptions, Hearing-Impaired Support, Haptic Feedback, Voice Navigation
//

import Foundation
import AVFoundation
import Speech
import CoreHaptics
import UIKit
import SwiftUI
import Combine

// MARK: - Audio Accessibility Manager
@MainActor
public class AudioAccessibilityManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var audioDescriptionsEnabled: Bool = false
    @Published public var captionsEnabled: Bool = false
    @Published public var hapticFeedbackEnabled: Bool = false
    @Published public var voiceNavigationEnabled: Bool = false
    @Published public var enhancedAudioEnabled: Bool = false
    @Published public var visualAudioIndicatorsEnabled: Bool = true
    @Published public var currentAudioDescription: String = ""
    @Published public var currentCaptions: [StreamCaption] = []
    @Published public var accessibilitySettings: AccessibilitySettings = .default
    @Published public var hearingProfile: HearingProfile = .normal
    @Published public var voiceCommands: [VoiceCommand] = []
    @Published public var hapticPatterns: [HapticPattern] = []
    
    // MARK: - Private Properties
    private var speechSynthesizer: AVSpeechSynthesizer
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine
    private var hapticEngine: CHHapticEngine?
    
    // Audio processing
    private var audioDescriptionGenerator: AudioDescriptionGenerator
    private var captionGenerator: CaptionGenerator
    private var hapticGenerator: HapticGenerator
    private var voiceCommandProcessor: VoiceCommandProcessor
    private var audioEnhancer: AudioEnhancer
    
    // Accessibility services
    private var screenReaderIntegration: ScreenReaderIntegration
    private var hearingAidSupport: HearingAidSupport
    private var visualAccessibilityFeatures: VisualAccessibilityFeatures
    
    private var cancellables = Set<AnyCancellable>()
    private var processingQueue: DispatchQueue
    
    // MARK: - Initialization
    public init() {
        self.speechSynthesizer = AVSpeechSynthesizer()
        self.audioEngine = AVAudioEngine()
        self.processingQueue = DispatchQueue(label: "audio.accessibility.processing", qos: .userInitiated)
        
        // Initialize components
        self.audioDescriptionGenerator = AudioDescriptionGenerator()
        self.captionGenerator = CaptionGenerator()
        self.hapticGenerator = HapticGenerator()
        self.voiceCommandProcessor = VoiceCommandProcessor()
        self.audioEnhancer = AudioEnhancer()
        self.screenReaderIntegration = ScreenReaderIntegration()
        self.hearingAidSupport = HearingAidSupport()
        self.visualAccessibilityFeatures = VisualAccessibilityFeatures()
        
        setupSpeechRecognition()
        setupHapticEngine()
        setupBindings()
        loadVoiceCommands()
        loadHapticPatterns()
    }
    
    // MARK: - Setup Methods
    private func setupSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer()
        
        // Request authorization
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized")
                @unknown default:
                    print("Unknown speech recognition status")
                }
            }
        }
    }
    
    private func setupHapticEngine() {
        // Check if haptic engine is available
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func setupBindings() {
        // Monitor accessibility settings changes
        $accessibilitySettings
            .sink { [weak self] settings in
                self?.updateAccessibilitySettings(settings)
            }
            .store(in: &cancellables)
        
        // Monitor hearing profile changes
        $hearingProfile
            .sink { [weak self] profile in
                self?.updateHearingProfile(profile)
            }
            .store(in: &cancellables)
        
        // Monitor voice navigation state
        $voiceNavigationEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.startVoiceNavigation()
                } else {
                    self?.stopVoiceNavigation()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadVoiceCommands() {
        voiceCommands = [
            VoiceCommand(phrase: "switch to stream one", action: .switchToStream("stream1")),
            VoiceCommand(phrase: "switch to stream two", action: .switchToStream("stream2")),
            VoiceCommand(phrase: "mute all", action: .muteAll),
            VoiceCommand(phrase: "unmute all", action: .unmuteAll),
            VoiceCommand(phrase: "increase volume", action: .adjustVolume(0.1)),
            VoiceCommand(phrase: "decrease volume", action: .adjustVolume(-0.1)),
            VoiceCommand(phrase: "enable spatial audio", action: .toggleSpatialAudio),
            VoiceCommand(phrase: "what's playing", action: .describeCurrentStream),
            VoiceCommand(phrase: "read captions", action: .readCaptions),
            VoiceCommand(phrase: "help", action: .showHelp)
        ]
    }
    
    private func loadHapticPatterns() {
        hapticPatterns = [
            HapticPattern(name: "Stream Switch", pattern: .streamSwitch),
            HapticPattern(name: "Voice Activity", pattern: .voiceActivity),
            HapticPattern(name: "Audio Peak", pattern: .audioPeak),
            HapticPattern(name: "Notification", pattern: .notification),
            HapticPattern(name: "Error", pattern: .error),
            HapticPattern(name: "Success", pattern: .success)
        ]
    }
    
    // MARK: - Audio Descriptions
    public func enableAudioDescriptions() {
        audioDescriptionsEnabled = true
        audioDescriptionGenerator.start()
    }
    
    public func disableAudioDescriptions() {
        audioDescriptionsEnabled = false
        audioDescriptionGenerator.stop()
    }
    
    public func generateAudioDescription(for event: AccessibilityEvent) {
        guard audioDescriptionsEnabled else { return }
        
        let description = audioDescriptionGenerator.generateDescription(for: event)
        currentAudioDescription = description
        
        // Speak the description
        speakText(description, priority: .high)
    }
    
    public func describeCurrentAudioState() {
        let description = audioDescriptionGenerator.generateCurrentStateDescription()
        speakText(description, priority: .immediate)
    }
    
    // MARK: - Captions and Transcription
    public func enableCaptions() {
        captionsEnabled = true
        captionGenerator.start()
    }
    
    public func disableCaptions() {
        captionsEnabled = false
        captionGenerator.stop()
        currentCaptions.removeAll()
    }
    
    public func processAudioForCaptions(_ buffer: AVAudioPCMBuffer, streamId: String) {
        guard captionsEnabled else { return }
        
        processingQueue.async { [weak self] in
            self?.captionGenerator.processAudio(buffer, for: streamId) { caption in
                DispatchQueue.main.async {
                    self?.addCaption(caption)
                }
            }
        }
    }
    
    private func addCaption(_ caption: StreamCaption) {
        currentCaptions.append(caption)
        
        // Limit number of captions displayed
        if currentCaptions.count > 10 {
            currentCaptions.removeFirst()
        }
        
        // Announce new captions if audio descriptions are enabled
        if audioDescriptionsEnabled && accessibilitySettings.announceCaptions {
            let announcement = "New caption from \(caption.streamName): \(caption.text)"
            speakText(announcement, priority: .medium)
        }
    }
    
    public func readCaptions() {
        let recentCaptions = currentCaptions.suffix(3)
        let captionText = recentCaptions.map { "\($0.streamName): \($0.text)" }.joined(separator: ". ")
        
        if captionText.isEmpty {
            speakText("No recent captions available", priority: .medium)
        } else {
            speakText("Recent captions: \(captionText)", priority: .medium)
        }
    }
    
    // MARK: - Haptic Feedback
    public func enableHapticFeedback() {
        hapticFeedbackEnabled = true
        try? hapticEngine?.start()
    }
    
    public func disableHapticFeedback() {
        hapticFeedbackEnabled = false
        hapticEngine?.stop { _ in }
    }
    
    public func playHapticPattern(_ pattern: HapticPatternType) {
        guard hapticFeedbackEnabled, let hapticEngine = hapticEngine else { return }
        
        do {
            let hapticPattern = hapticGenerator.createPattern(for: pattern)
            let player = try hapticEngine.makePlayer(with: hapticPattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
    
    public func playCustomHaptic(intensity: Float, duration: TimeInterval) {
        guard hapticFeedbackEnabled, let hapticEngine = hapticEngine else { return }
        
        do {
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0,
                duration: duration
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play custom haptic: \(error)")
        }
    }
    
    // MARK: - Voice Navigation
    public func startVoiceNavigation() {
        guard let speechRecognizer = speechRecognizer else { return }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                let spokenText = result.bestTranscription.formattedString
                self?.processVoiceCommand(spokenText)
            }
            
            if error != nil {
                self?.stopVoiceNavigation()
            }
        }
        
        // Start audio engine for voice recognition
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine for voice navigation: \(error)")
        }
    }
    
    public func stopVoiceNavigation() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func processVoiceCommand(_ spokenText: String) {
        let processedCommand = voiceCommandProcessor.processCommand(spokenText, availableCommands: voiceCommands)
        
        if let command = processedCommand {
            executeVoiceCommand(command)
        }
    }
    
    private func executeVoiceCommand(_ command: VoiceCommand) {
        switch command.action {
        case .switchToStream(let streamId):
            NotificationCenter.default.post(name: .switchToStream, object: streamId)
            speakText("Switched to \(streamId)", priority: .medium)
            playHapticPattern(.streamSwitch)
            
        case .muteAll:
            NotificationCenter.default.post(name: .muteAllStreams, object: nil)
            speakText("All streams muted", priority: .medium)
            
        case .unmuteAll:
            NotificationCenter.default.post(name: .unmuteAllStreams, object: nil)
            speakText("All streams unmuted", priority: .medium)
            
        case .adjustVolume(let delta):
            NotificationCenter.default.post(name: .adjustMasterVolume, object: delta)
            let direction = delta > 0 ? "increased" : "decreased"
            speakText("Volume \(direction)", priority: .medium)
            
        case .toggleSpatialAudio:
            NotificationCenter.default.post(name: .toggleSpatialAudio, object: nil)
            speakText("Spatial audio toggled", priority: .medium)
            
        case .describeCurrentStream:
            describeCurrentAudioState()
            
        case .readCaptions:
            readCaptions()
            
        case .showHelp:
            speakHelp()
        }
    }
    
    // MARK: - Audio Enhancement
    public func enableAudioEnhancement() {
        enhancedAudioEnabled = true
        audioEnhancer.start()
    }
    
    public func disableAudioEnhancement() {
        enhancedAudioEnabled = false
        audioEnhancer.stop()
    }
    
    public func processAudioForEnhancement(_ buffer: AVAudioPCMBuffer, for profile: HearingProfile) -> AVAudioPCMBuffer {
        guard enhancedAudioEnabled else { return buffer }
        
        return audioEnhancer.enhanceAudio(buffer, for: profile)
    }
    
    // MARK: - Visual Accessibility
    public func enableVisualAudioIndicators() {
        visualAudioIndicatorsEnabled = true
        visualAccessibilityFeatures.enableIndicators()
    }
    
    public func disableVisualAudioIndicators() {
        visualAudioIndicatorsEnabled = false
        visualAccessibilityFeatures.disableIndicators()
    }
    
    public func updateVisualIndicators(for audioData: [String: Float]) {
        guard visualAudioIndicatorsEnabled else { return }
        
        visualAccessibilityFeatures.updateIndicators(audioData)
    }
    
    // MARK: - Hearing Aid Support
    public func enableHearingAidSupport() {
        hearingAidSupport.enable()
    }
    
    public func disableHearingAidSupport() {
        hearingAidSupport.disable()
    }
    
    public func configureHearingAidSettings(_ settings: HearingAidSettings) {
        hearingAidSupport.configure(settings)
    }
    
    // MARK: - Speech Synthesis
    private func speakText(_ text: String, priority: SpeechPriority) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = accessibilitySettings.speechRate
        utterance.volume = accessibilitySettings.speechVolume
        utterance.voice = AVSpeechSynthesisVoice(language: accessibilitySettings.speechLanguage)
        
        // Handle priority
        switch priority {
        case .immediate:
            speechSynthesizer.stopSpeaking(at: .immediate)
            speechSynthesizer.speak(utterance)
        case .high:
            speechSynthesizer.stopSpeaking(at: .word)
            speechSynthesizer.speak(utterance)
        case .medium:
            speechSynthesizer.speak(utterance)
        case .low:
            if !speechSynthesizer.isSpeaking {
                speechSynthesizer.speak(utterance)
            }
        }
    }
    
    private func speakHelp() {
        let helpText = """
        Available voice commands:
        Switch to stream one or two.
        Mute all or unmute all.
        Increase or decrease volume.
        Enable spatial audio.
        What's playing to describe current stream.
        Read captions for recent captions.
        """
        speakText(helpText, priority: .immediate)
    }
    
    // MARK: - Settings Management
    private func updateAccessibilitySettings(_ settings: AccessibilitySettings) {
        audioDescriptionGenerator.updateSettings(settings)
        captionGenerator.updateSettings(settings)
        hapticGenerator.updateSettings(settings)
        audioEnhancer.updateSettings(settings)
    }
    
    private func updateHearingProfile(_ profile: HearingProfile) {
        audioEnhancer.updateHearingProfile(profile)
        hearingAidSupport.updateProfile(profile)
    }
    
    // MARK: - Accessibility Information
    public func getAccessibilityInfo() -> AccessibilityInfo {
        return AccessibilityInfo(
            audioDescriptionsEnabled: audioDescriptionsEnabled,
            captionsEnabled: captionsEnabled,
            hapticFeedbackEnabled: hapticFeedbackEnabled,
            voiceNavigationEnabled: voiceNavigationEnabled,
            enhancedAudioEnabled: enhancedAudioEnabled,
            visualIndicatorsEnabled: visualAudioIndicatorsEnabled,
            hearingProfile: hearingProfile,
            settings: accessibilitySettings,
            availableVoiceCommands: voiceCommands.map { $0.phrase },
            currentCaptionCount: currentCaptions.count
        )
    }
}

// MARK: - Supporting Types

public enum AccessibilityEvent {
    case streamAdded(String)
    case streamRemoved(String)
    case streamSwitched(from: String?, to: String)
    case volumeChanged(Float)
    case muteToggled(String, Bool)
    case spatialAudioToggled(Bool)
    case voiceActivityDetected(String)
    case errorOccurred(String)
}

public struct StreamCaption: Identifiable, Codable {
    public let id: String
    public let streamId: String
    public let streamName: String
    public let text: String
    public let confidence: Float
    public let timestamp: Date
    public let language: String
    
    public init(id: String = UUID().uuidString, streamId: String, streamName: String, text: String, confidence: Float, timestamp: Date = Date(), language: String = "en") {
        self.id = id
        self.streamId = streamId
        self.streamName = streamName
        self.text = text
        self.confidence = confidence
        self.timestamp = timestamp
        self.language = language
    }
}

public struct VoiceCommand: Identifiable {
    public let id: String
    public let phrase: String
    public let action: VoiceCommandAction
    
    public init(id: String = UUID().uuidString, phrase: String, action: VoiceCommandAction) {
        self.id = id
        self.phrase = phrase
        self.action = action
    }
}

public enum VoiceCommandAction {
    case switchToStream(String)
    case muteAll
    case unmuteAll
    case adjustVolume(Float)
    case toggleSpatialAudio
    case describeCurrentStream
    case readCaptions
    case showHelp
}

public struct HapticPattern: Identifiable {
    public let id: String
    public let name: String
    public let pattern: HapticPatternType
    
    public init(id: String = UUID().uuidString, name: String, pattern: HapticPatternType) {
        self.id = id
        self.name = name
        self.pattern = pattern
    }
}

public enum HapticPatternType {
    case streamSwitch
    case voiceActivity
    case audioPeak
    case notification
    case error
    case success
}

public enum HearingProfile: String, CaseIterable, Codable {
    case normal = "normal"
    case mildLoss = "mildLoss"
    case moderateLoss = "moderateLoss"
    case severeLoss = "severeLoss"
    case hearingAid = "hearingAid"
    case cochlearImplant = "cochlearImplant"
    
    public var displayName: String {
        switch self {
        case .normal: return "Normal Hearing"
        case .mildLoss: return "Mild Hearing Loss"
        case .moderateLoss: return "Moderate Hearing Loss"
        case .severeLoss: return "Severe Hearing Loss"
        case .hearingAid: return "Hearing Aid User"
        case .cochlearImplant: return "Cochlear Implant User"
        }
    }
}

public enum SpeechPriority {
    case immediate
    case high
    case medium
    case low
}

public struct AccessibilitySettings: Codable {
    public var speechRate: Float = 0.5
    public var speechVolume: Float = 1.0
    public var speechLanguage: String = "en-US"
    public var announceCaptions: Bool = true
    public var announceStreamChanges: Bool = true
    public var announceVolumeChanges: Bool = false
    public var hapticIntensity: Float = 1.0
    public var visualIndicatorSize: Float = 1.0
    public var contrastLevel: Float = 1.0
    public var reducedMotion: Bool = false
    
    public static let `default` = AccessibilitySettings()
}

public struct HearingAidSettings: Codable {
    public var frequencyResponse: [Float] = []
    public var compressionRatio: Float = 2.0
    public var noiseReduction: Float = 0.5
    public var directionalMicrophone: Bool = true
    public var feedbackSuppression: Bool = true
    
    public static let `default` = HearingAidSettings()
}

public struct AccessibilityInfo {
    public let audioDescriptionsEnabled: Bool
    public let captionsEnabled: Bool
    public let hapticFeedbackEnabled: Bool
    public let voiceNavigationEnabled: Bool
    public let enhancedAudioEnabled: Bool
    public let visualIndicatorsEnabled: Bool
    public let hearingProfile: HearingProfile
    public let settings: AccessibilitySettings
    public let availableVoiceCommands: [String]
    public let currentCaptionCount: Int
}

// MARK: - Supporting Classes

class AudioDescriptionGenerator {
    private var isRunning: Bool = false
    private var settings: AccessibilitySettings = .default
    
    func start() {
        isRunning = true
    }
    
    func stop() {
        isRunning = false
    }
    
    func generateDescription(for event: AccessibilityEvent) -> String {
        guard isRunning else { return "" }
        
        switch event {
        case .streamAdded(let streamId):
            return "New stream added: \(streamId)"
        case .streamRemoved(let streamId):
            return "Stream removed: \(streamId)"
        case .streamSwitched(let from, let to):
            if let from = from {
                return "Audio switched from \(from) to \(to)"
            } else {
                return "Audio switched to \(to)"
            }
        case .volumeChanged(let volume):
            return "Volume changed to \(Int(volume * 100)) percent"
        case .muteToggled(let streamId, let muted):
            return "Stream \(streamId) \(muted ? "muted" : "unmuted")"
        case .spatialAudioToggled(let enabled):
            return "Spatial audio \(enabled ? "enabled" : "disabled")"
        case .voiceActivityDetected(let streamId):
            return "Voice activity detected on \(streamId)"
        case .errorOccurred(let message):
            return "Error: \(message)"
        }
    }
    
    func generateCurrentStateDescription() -> String {
        // Generate description of current audio state
        return "Describing current audio state with multiple streams"
    }
    
    func updateSettings(_ settings: AccessibilitySettings) {
        self.settings = settings
    }
}

class CaptionGenerator {
    private var isRunning: Bool = false
    private var settings: AccessibilitySettings = .default
    private var speechRecognizers: [String: SFSpeechRecognizer] = [:]
    
    func start() {
        isRunning = true
    }
    
    func stop() {
        isRunning = false
    }
    
    func processAudio(_ buffer: AVAudioPCMBuffer, for streamId: String, completion: @escaping (StreamCaption) -> Void) {
        guard isRunning else { return }
        
        // Perform speech recognition on audio buffer
        // This is a simplified implementation
        let recognizedText = "Sample caption text for stream \(streamId)"
        
        let caption = StreamCaption(
            streamId: streamId,
            streamName: "Stream \(streamId)",
            text: recognizedText,
            confidence: 0.95,
            language: settings.speechLanguage
        )
        
        completion(caption)
    }
    
    func updateSettings(_ settings: AccessibilitySettings) {
        self.settings = settings
    }
}

class HapticGenerator {
    private var settings: AccessibilitySettings = .default
    
    func createPattern(for type: HapticPatternType) -> CHHapticPattern {
        let events: [CHHapticEvent]
        
        switch type {
        case .streamSwitch:
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0.1)
            ]
            
        case .voiceActivity:
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ], relativeTime: 0, duration: 0.2)
            ]
            
        case .audioPeak:
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ], relativeTime: 0)
            ]
            
        case .notification:
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0)
            ]
            
        case .error:
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0.1),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ], relativeTime: 0.2)
            ]
            
        case .success:
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ], relativeTime: 0.15)
            ]
        }
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            // Return empty pattern on error
            return try! CHHapticPattern(events: [], parameters: [])
        }
    }
    
    func updateSettings(_ settings: AccessibilitySettings) {
        self.settings = settings
    }
}

class VoiceCommandProcessor {
    func processCommand(_ spokenText: String, availableCommands: [VoiceCommand]) -> VoiceCommand? {
        let lowercaseText = spokenText.lowercased()
        
        // Find best matching command
        for command in availableCommands {
            if lowercaseText.contains(command.phrase.lowercased()) {
                return command
            }
        }
        
        // Fuzzy matching could be implemented here
        return nil
    }
}

class AudioEnhancer {
    private var isRunning: Bool = false
    private var settings: AccessibilitySettings = .default
    private var hearingProfile: HearingProfile = .normal
    
    func start() {
        isRunning = true
    }
    
    func stop() {
        isRunning = false
    }
    
    func enhanceAudio(_ buffer: AVAudioPCMBuffer, for profile: HearingProfile) -> AVAudioPCMBuffer {
        guard isRunning else { return buffer }
        
        // Apply audio enhancements based on hearing profile
        switch profile {
        case .normal:
            return buffer
        case .mildLoss:
            return applyMildEnhancement(buffer)
        case .moderateLoss:
            return applyModerateEnhancement(buffer)
        case .severeLoss:
            return applySevereEnhancement(buffer)
        case .hearingAid:
            return applyHearingAidEnhancement(buffer)
        case .cochlearImplant:
            return applyCochlearImplantEnhancement(buffer)
        }
    }
    
    private func applyMildEnhancement(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // Mild enhancement: slight high-frequency boost
        return buffer
    }
    
    private func applyModerateEnhancement(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // Moderate enhancement: more aggressive high-frequency boost, some compression
        return buffer
    }
    
    private func applySevereEnhancement(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // Severe enhancement: significant frequency shaping, compression, noise reduction
        return buffer
    }
    
    private func applyHearingAidEnhancement(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // Hearing aid enhancement: optimized for hearing aid processing
        return buffer
    }
    
    private func applyCochlearImplantEnhancement(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // Cochlear implant enhancement: specialized processing
        return buffer
    }
    
    func updateSettings(_ settings: AccessibilitySettings) {
        self.settings = settings
    }
    
    func updateHearingProfile(_ profile: HearingProfile) {
        self.hearingProfile = profile
    }
}

class ScreenReaderIntegration {
    func announceAudioEvent(_ event: AccessibilityEvent) {
        // Integrate with VoiceOver and other screen readers
        let announcement = generateAnnouncement(for: event)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    private func generateAnnouncement(for event: AccessibilityEvent) -> String {
        switch event {
        case .streamSwitched(let from, let to):
            return "Audio switched to \(to)"
        case .volumeChanged(let volume):
            return "Volume \(Int(volume * 100)) percent"
        default:
            return "Audio event occurred"
        }
    }
}

class HearingAidSupport {
    private var isEnabled: Bool = false
    private var settings: HearingAidSettings = .default
    
    func enable() {
        isEnabled = true
        // Enable Made for iPhone hearing aid features
    }
    
    func disable() {
        isEnabled = false
    }
    
    func configure(_ settings: HearingAidSettings) {
        self.settings = settings
    }
    
    func updateProfile(_ profile: HearingProfile) {
        // Update hearing aid settings based on profile
    }
}

class VisualAccessibilityFeatures {
    private var isEnabled: Bool = false
    
    func enableIndicators() {
        isEnabled = true
    }
    
    func disableIndicators() {
        isEnabled = false
    }
    
    func updateIndicators(_ audioData: [String: Float]) {
        guard isEnabled else { return }
        
        // Update visual indicators based on audio data
        // This would typically involve updating UI elements
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let switchToStream = Notification.Name("switchToStream")
    static let muteAllStreams = Notification.Name("muteAllStreams")
    static let unmuteAllStreams = Notification.Name("unmuteAllStreams")
    static let adjustMasterVolume = Notification.Name("adjustMasterVolume")
    static let toggleSpatialAudio = Notification.Name("toggleSpatialAudio")
}