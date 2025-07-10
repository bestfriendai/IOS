//
//  AudioVisualizationEngine.swift
//  StreamyyyApp
//
//  Real-time Audio Visualization System
//  Features: Spectrum Analysis, Waveform Display, Audio Level Meters, Visual Effects
//

import Foundation
import AVFoundation
import Accelerate
import SwiftUI
import Metal
import MetalKit
import CoreGraphics
import Combine

// MARK: - Audio Visualization Engine
@MainActor
public class AudioVisualizationEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isVisualizationEnabled: Bool = true
    @Published public var currentVisualizationType: VisualizationType = .spectrum
    @Published public var visualizationStyle: VisualizationStyle = .modern
    @Published public var spectrumData: [Float] = []
    @Published public var waveformData: [Float] = []
    @Published public var audioLevels: [String: AudioLevelData] = [:]
    @Published public var peakFrequencies: [Float] = []
    @Published public var spectralCentroid: Float = 0.0
    @Published public var spectralRolloff: Float = 0.0
    @Published public var zeroCrossingRate: Float = 0.0
    @Published public var mfccCoefficients: [Float] = []
    @Published public var beatDetectionEnabled: Bool = false
    @Published public var detectedBPM: Float = 0.0
    @Published public var visualizationSettings: VisualizationSettings = .default
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine
    private var fftAnalyzer: FFTAnalyzer
    private var waveformAnalyzer: WaveformAnalyzer
    private var spectrumAnalyzer: SpectrumAnalyzer
    private var audioLevelMeter: AudioLevelMeter
    private var beatDetector: BeatDetector
    private var featureExtractor: AudioFeatureExtractor
    
    // Metal rendering
    private var metalDevice: MTLDevice?
    private var metalCommandQueue: MTLCommandQueue?
    private var visualizationRenderer: VisualizationRenderer?
    
    // Processing queues
    private var analysisQueue: DispatchQueue
    private var renderingQueue: DispatchQueue
    private var cancellables = Set<AnyCancellable>()
    
    // Audio buffers
    private var audioBuffers: [String: CircularAudioBuffer] = [:]
    private var analysisBuffers: [String: AnalysisBuffer] = [:]
    
    // Visualization data
    private var visualizationHistory: VisualizationHistory
    private var smoothingFilter: SmoothingFilter
    private var colorPalette: ColorPalette
    
    // Performance monitoring
    private var performanceMonitor: VisualizationPerformanceMonitor
    private var frameRate: Float = 60.0
    private var targetFrameRate: Float = 60.0
    
    // MARK: - Initialization
    public init() {
        self.audioEngine = AVAudioEngine()
        self.fftAnalyzer = FFTAnalyzer()
        self.waveformAnalyzer = WaveformAnalyzer()
        self.spectrumAnalyzer = SpectrumAnalyzer()
        self.audioLevelMeter = AudioLevelMeter()
        self.beatDetector = BeatDetector()
        self.featureExtractor = AudioFeatureExtractor()
        
        // Initialize Metal
        self.metalDevice = MTLCreateSystemDefaultDevice()
        self.metalCommandQueue = metalDevice?.makeCommandQueue()
        
        // Initialize queues
        self.analysisQueue = DispatchQueue(label: "audio.visualization.analysis", qos: .userInitiated)
        self.renderingQueue = DispatchQueue(label: "audio.visualization.rendering", qos: .userInitiated)
        
        // Initialize visualization components
        self.visualizationHistory = VisualizationHistory()
        self.smoothingFilter = SmoothingFilter()
        self.colorPalette = ColorPalette()
        self.performanceMonitor = VisualizationPerformanceMonitor()
        
        // Setup Metal rendering
        setupMetalRendering()
        
        // Setup bindings
        setupBindings()
        
        // Initialize empty data arrays
        initializeVisualizationData()
    }
    
    // MARK: - Setup Methods
    private func setupMetalRendering() {
        guard let metalDevice = metalDevice,
              let metalCommandQueue = metalCommandQueue else { return }
        
        visualizationRenderer = VisualizationRenderer(
            device: metalDevice,
            commandQueue: metalCommandQueue
        )
    }
    
    private func setupBindings() {
        // Monitor visualization settings
        $visualizationSettings
            .sink { [weak self] settings in
                self?.updateVisualizationSettings(settings)
            }
            .store(in: &cancellables)
        
        // Monitor beat detection
        $beatDetectionEnabled
            .sink { [weak self] enabled in
                self?.beatDetector.setEnabled(enabled)
            }
            .store(in: &cancellables)
        
        // Monitor visualization type changes
        $currentVisualizationType
            .sink { [weak self] type in
                self?.updateVisualizationType(type)
            }
            .store(in: &cancellables)
    }
    
    private func initializeVisualizationData() {
        // Initialize with empty data
        spectrumData = Array(repeating: 0.0, count: 512)
        waveformData = Array(repeating: 0.0, count: 1024)
        peakFrequencies = Array(repeating: 0.0, count: 10)
        mfccCoefficients = Array(repeating: 0.0, count: 13)
    }
    
    // MARK: - Audio Stream Management
    public func addAudioStream(_ stream: Stream) {
        let audioBuffer = CircularAudioBuffer(capacity: 8192)
        let analysisBuffer = AnalysisBuffer(capacity: 2048)
        
        audioBuffers[stream.id] = audioBuffer
        analysisBuffers[stream.id] = analysisBuffer
        
        // Initialize audio level data
        audioLevels[stream.id] = AudioLevelData()
        
        // Setup audio tap
        setupAudioTap(for: stream)
    }
    
    public func removeAudioStream(_ streamId: String) {
        audioBuffers.removeValue(forKey: streamId)
        analysisBuffers.removeValue(forKey: streamId)
        audioLevels.removeValue(forKey: streamId)
    }
    
    private func setupAudioTap(for stream: Stream) {
        // This would typically be integrated with the audio engine
        // For now, we'll simulate the setup
        
        // Install audio tap on the stream's audio node
        // audioNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
        //     self.processAudioBuffer(buffer, for: stream.id)
        // }
    }
    
    // MARK: - Audio Processing
    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer, for streamId: String) {
        guard let audioBuffer = audioBuffers[streamId],
              let analysisBuffer = analysisBuffers[streamId] else { return }
        
        // Add audio data to buffer
        audioBuffer.append(buffer)
        
        // Process audio analysis
        analysisQueue.async { [weak self] in
            self?.performAudioAnalysis(audioBuffer: audioBuffer, analysisBuffer: analysisBuffer, streamId: streamId)
        }
    }
    
    private func performAudioAnalysis(audioBuffer: CircularAudioBuffer, analysisBuffer: AnalysisBuffer, streamId: String) {
        // Extract audio data
        let audioData = audioBuffer.getLatestData(length: 2048)
        
        // Perform FFT analysis
        let spectrumData = fftAnalyzer.performFFT(audioData)
        
        // Perform waveform analysis
        let waveformData = waveformAnalyzer.analyzeWaveform(audioData)
        
        // Calculate audio levels
        let levelData = audioLevelMeter.calculateLevels(audioData)
        
        // Extract audio features
        let features = featureExtractor.extractFeatures(audioData)
        
        // Beat detection
        var detectedBeat: BeatInfo? = nil
        if beatDetectionEnabled {
            detectedBeat = beatDetector.detectBeat(audioData)
        }
        
        // Update analysis buffer
        analysisBuffer.update(
            spectrum: spectrumData,
            waveform: waveformData,
            levels: levelData,
            features: features,
            beat: detectedBeat
        )
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            self?.updateVisualizationData(from: analysisBuffer, streamId: streamId)
        }
    }
    
    private func updateVisualizationData(from buffer: AnalysisBuffer, streamId: String) {
        // Update main visualization data (typically from the active stream)
        if let firstStreamId = audioBuffers.keys.first, streamId == firstStreamId {
            spectrumData = buffer.spectrum
            waveformData = buffer.waveform
            spectralCentroid = buffer.features.spectralCentroid
            spectralRolloff = buffer.features.spectralRolloff
            zeroCrossingRate = buffer.features.zeroCrossingRate
            mfccCoefficients = buffer.features.mfccCoefficients
            peakFrequencies = buffer.features.peakFrequencies
            
            if let beat = buffer.beat {
                detectedBPM = beat.bpm
            }
        }
        
        // Update stream-specific audio levels
        audioLevels[streamId] = buffer.levels
        
        // Update visualization history
        visualizationHistory.addFrame(
            spectrum: buffer.spectrum,
            waveform: buffer.waveform,
            levels: buffer.levels,
            timestamp: Date()
        )
        
        // Apply smoothing
        applySmoothing()
    }
    
    private func applySmoothing() {
        // Apply smoothing filters to reduce flickering
        spectrumData = smoothingFilter.smoothSpectrum(spectrumData)
        waveformData = smoothingFilter.smoothWaveform(waveformData)
        
        // Smooth audio levels
        for (streamId, levelData) in audioLevels {
            audioLevels[streamId] = smoothingFilter.smoothLevels(levelData)
        }
    }
    
    // MARK: - Visualization Rendering
    public func renderVisualization(in view: MTKView) {
        guard let renderer = visualizationRenderer else { return }
        
        renderingQueue.async { [weak self] in
            self?.performVisualizationRender(renderer: renderer, view: view)
        }
    }
    
    private func performVisualizationRender(renderer: VisualizationRenderer, view: MTKView) {
        let renderData = VisualizationRenderData(
            spectrumData: spectrumData,
            waveformData: waveformData,
            audioLevels: audioLevels,
            visualizationType: currentVisualizationType,
            visualizationStyle: visualizationStyle,
            settings: visualizationSettings,
            colorPalette: colorPalette
        )
        
        renderer.render(renderData, in: view)
        
        // Update performance metrics
        performanceMonitor.recordFrame()
    }
    
    // MARK: - Visualization Controls
    public func setVisualizationType(_ type: VisualizationType) {
        currentVisualizationType = type
        updateVisualizationType(type)
    }
    
    public func setVisualizationStyle(_ style: VisualizationStyle) {
        visualizationStyle = style
        updateVisualizationStyle(style)
    }
    
    public func setVisualizationEnabled(_ enabled: Bool) {
        isVisualizationEnabled = enabled
        
        if enabled {
            startVisualization()
        } else {
            stopVisualization()
        }
    }
    
    private func updateVisualizationType(_ type: VisualizationType) {
        // Configure analyzers based on visualization type
        switch type {
        case .spectrum:
            fftAnalyzer.setConfiguration(.spectrum)
        case .waveform:
            waveformAnalyzer.setConfiguration(.realTime)
        case .spectrogram:
            fftAnalyzer.setConfiguration(.spectrogram)
        case .levelMeter:
            audioLevelMeter.setConfiguration(.detailed)
        case .combined:
            fftAnalyzer.setConfiguration(.spectrum)
            waveformAnalyzer.setConfiguration(.realTime)
        }
    }
    
    private func updateVisualizationStyle(_ style: VisualizationStyle) {
        // Update color palette and visual style
        colorPalette.updateForStyle(style)
        visualizationRenderer?.updateStyle(style)
    }
    
    private func updateVisualizationSettings(_ settings: VisualizationSettings) {
        // Update various visualization parameters
        fftAnalyzer.updateSettings(settings.fftSettings)
        waveformAnalyzer.updateSettings(settings.waveformSettings)
        audioLevelMeter.updateSettings(settings.levelMeterSettings)
        smoothingFilter.updateSettings(settings.smoothingSettings)
        colorPalette.updateSettings(settings.colorSettings)
    }
    
    // MARK: - Audio Feature Analysis
    public func getAudioFeatures(for streamId: String) -> AudioFeatures? {
        guard let analysisBuffer = analysisBuffers[streamId] else { return nil }
        return analysisBuffer.features
    }
    
    public func getSpectrumPeaks(for streamId: String, count: Int = 10) -> [SpectrumPeak] {
        guard let analysisBuffer = analysisBuffers[streamId] else { return [] }
        return spectrumAnalyzer.findPeaks(in: analysisBuffer.spectrum, count: count)
    }
    
    public func getSpectralCentroid(for streamId: String) -> Float {
        guard let analysisBuffer = analysisBuffers[streamId] else { return 0.0 }
        return analysisBuffer.features.spectralCentroid
    }
    
    public func getSpectralRolloff(for streamId: String) -> Float {
        guard let analysisBuffer = analysisBuffers[streamId] else { return 0.0 }
        return analysisBuffer.features.spectralRolloff
    }
    
    // MARK: - Beat Detection
    public func setBeatDetectionEnabled(_ enabled: Bool) {
        beatDetectionEnabled = enabled
        beatDetector.setEnabled(enabled)
    }
    
    public func getBeatInfo() -> BeatInfo? {
        return beatDetector.getCurrentBeatInfo()
    }
    
    public func getBPM() -> Float {
        return detectedBPM
    }
    
    // MARK: - Visualization History
    public func getVisualizationHistory(duration: TimeInterval) -> [VisualizationFrame] {
        return visualizationHistory.getFrames(for: duration)
    }
    
    public func clearVisualizationHistory() {
        visualizationHistory.clear()
    }
    
    // MARK: - Performance and Control
    public func setTargetFrameRate(_ frameRate: Float) {
        targetFrameRate = frameRate
        performanceMonitor.setTargetFrameRate(frameRate)
    }
    
    public func getPerformanceMetrics() -> VisualizationPerformanceMetrics {
        return performanceMonitor.getMetrics()
    }
    
    public func startVisualization() {
        performanceMonitor.startMonitoring()
    }
    
    public func stopVisualization() {
        performanceMonitor.stopMonitoring()
    }
    
    // MARK: - Presets
    public func loadVisualizationPreset(_ preset: VisualizationPreset) {
        currentVisualizationType = preset.visualizationType
        visualizationStyle = preset.visualizationStyle
        visualizationSettings = preset.settings
        beatDetectionEnabled = preset.beatDetectionEnabled
        
        // Apply preset
        updateVisualizationType(preset.visualizationType)
        updateVisualizationStyle(preset.visualizationStyle)
        updateVisualizationSettings(preset.settings)
    }
    
    public func saveVisualizationPreset(name: String) -> VisualizationPreset {
        return VisualizationPreset(
            id: UUID().uuidString,
            name: name,
            visualizationType: currentVisualizationType,
            visualizationStyle: visualizationStyle,
            settings: visualizationSettings,
            beatDetectionEnabled: beatDetectionEnabled
        )
    }
    
    // MARK: - Visualization Info
    public func getVisualizationInfo() -> VisualizationInfo {
        return VisualizationInfo(
            isEnabled: isVisualizationEnabled,
            currentType: currentVisualizationType,
            currentStyle: visualizationStyle,
            streamCount: audioBuffers.count,
            frameRate: frameRate,
            targetFrameRate: targetFrameRate,
            performanceMetrics: performanceMonitor.getMetrics(),
            settings: visualizationSettings
        )
    }
}

// MARK: - Supporting Types

public enum VisualizationType: String, CaseIterable, Codable {
    case spectrum = "spectrum"
    case waveform = "waveform"
    case spectrogram = "spectrogram"
    case levelMeter = "levelMeter"
    case combined = "combined"
    
    public var displayName: String {
        switch self {
        case .spectrum: return "Spectrum"
        case .waveform: return "Waveform"
        case .spectrogram: return "Spectrogram"
        case .levelMeter: return "Level Meter"
        case .combined: return "Combined"
        }
    }
}

public enum VisualizationStyle: String, CaseIterable, Codable {
    case modern = "modern"
    case classic = "classic"
    case neon = "neon"
    case minimal = "minimal"
    case retro = "retro"
    
    public var displayName: String {
        switch self {
        case .modern: return "Modern"
        case .classic: return "Classic"
        case .neon: return "Neon"
        case .minimal: return "Minimal"
        case .retro: return "Retro"
        }
    }
}

public struct VisualizationSettings: Codable {
    public var fftSettings: FFTSettings
    public var waveformSettings: WaveformSettings
    public var levelMeterSettings: LevelMeterSettings
    public var smoothingSettings: SmoothingSettings
    public var colorSettings: ColorSettings
    
    public static let `default` = VisualizationSettings(
        fftSettings: FFTSettings.default,
        waveformSettings: WaveformSettings.default,
        levelMeterSettings: LevelMeterSettings.default,
        smoothingSettings: SmoothingSettings.default,
        colorSettings: ColorSettings.default
    )
}

public struct FFTSettings: Codable {
    public var fftSize: Int
    public var windowType: WindowType
    public var overlapFactor: Float
    public var frequencyRange: ClosedRange<Float>
    
    public static let `default` = FFTSettings(
        fftSize: 2048,
        windowType: .hann,
        overlapFactor: 0.5,
        frequencyRange: 20...20000
    )
}

public struct WaveformSettings: Codable {
    public var bufferSize: Int
    public var timeRange: TimeInterval
    public var amplitudeScale: Float
    
    public static let `default` = WaveformSettings(
        bufferSize: 1024,
        timeRange: 0.1,
        amplitudeScale: 1.0
    )
}

public struct LevelMeterSettings: Codable {
    public var peakHoldTime: TimeInterval
    public var decayRate: Float
    public var rangeDB: ClosedRange<Float>
    
    public static let `default` = LevelMeterSettings(
        peakHoldTime: 2.0,
        decayRate: 0.1,
        rangeDB: -60...0
    )
}

public struct SmoothingSettings: Codable {
    public var spectrumSmoothing: Float
    public var waveformSmoothing: Float
    public var levelSmoothing: Float
    
    public static let `default` = SmoothingSettings(
        spectrumSmoothing: 0.7,
        waveformSmoothing: 0.5,
        levelSmoothing: 0.8
    )
}

public struct ColorSettings: Codable {
    public var primaryColor: String
    public var secondaryColor: String
    public var backgroundColor: String
    public var gradientEnabled: Bool
    
    public static let `default` = ColorSettings(
        primaryColor: "#FF6B6B",
        secondaryColor: "#4ECDC4",
        backgroundColor: "#2C3E50",
        gradientEnabled: true
    )
}

public enum WindowType: String, CaseIterable, Codable {
    case hann = "hann"
    case hamming = "hamming"
    case blackman = "blackman"
    case rectangular = "rectangular"
    
    public var displayName: String {
        switch self {
        case .hann: return "Hann"
        case .hamming: return "Hamming"
        case .blackman: return "Blackman"
        case .rectangular: return "Rectangular"
        }
    }
}

public struct AudioLevelData: Codable {
    public var rms: Float = 0.0
    public var peak: Float = 0.0
    public var averageLevel: Float = 0.0
    public var dynamicRange: Float = 0.0
    public var clipCount: Int = 0
    public var timestamp: Date = Date()
    
    public init() {}
}

public struct AudioFeatures: Codable {
    public var spectralCentroid: Float = 0.0
    public var spectralRolloff: Float = 0.0
    public var zeroCrossingRate: Float = 0.0
    public var mfccCoefficients: [Float] = []
    public var peakFrequencies: [Float] = []
    public var spectralFlux: Float = 0.0
    public var spectralFlatness: Float = 0.0
    public var chroma: [Float] = []
    
    public init() {}
}

public struct BeatInfo: Codable {
    public var bpm: Float
    public var confidence: Float
    public var timestamp: Date
    public var beatStrength: Float
    
    public init(bpm: Float, confidence: Float, timestamp: Date, beatStrength: Float) {
        self.bpm = bpm
        self.confidence = confidence
        self.timestamp = timestamp
        self.beatStrength = beatStrength
    }
}

public struct SpectrumPeak: Codable {
    public var frequency: Float
    public var magnitude: Float
    public var phase: Float
    
    public init(frequency: Float, magnitude: Float, phase: Float) {
        self.frequency = frequency
        self.magnitude = magnitude
        self.phase = phase
    }
}

public struct VisualizationFrame: Codable {
    public var spectrum: [Float]
    public var waveform: [Float]
    public var levels: AudioLevelData
    public var timestamp: Date
    
    public init(spectrum: [Float], waveform: [Float], levels: AudioLevelData, timestamp: Date) {
        self.spectrum = spectrum
        self.waveform = waveform
        self.levels = levels
        self.timestamp = timestamp
    }
}

public struct VisualizationPreset: Codable, Identifiable {
    public let id: String
    public let name: String
    public let visualizationType: VisualizationType
    public let visualizationStyle: VisualizationStyle
    public let settings: VisualizationSettings
    public let beatDetectionEnabled: Bool
    
    public init(id: String, name: String, visualizationType: VisualizationType, visualizationStyle: VisualizationStyle, settings: VisualizationSettings, beatDetectionEnabled: Bool) {
        self.id = id
        self.name = name
        self.visualizationType = visualizationType
        self.visualizationStyle = visualizationStyle
        self.settings = settings
        self.beatDetectionEnabled = beatDetectionEnabled
    }
}

public struct VisualizationInfo {
    public let isEnabled: Bool
    public let currentType: VisualizationType
    public let currentStyle: VisualizationStyle
    public let streamCount: Int
    public let frameRate: Float
    public let targetFrameRate: Float
    public let performanceMetrics: VisualizationPerformanceMetrics
    public let settings: VisualizationSettings
}

public struct VisualizationPerformanceMetrics {
    public var averageFrameRate: Float = 0.0
    public var frameDrops: Int = 0
    public var cpuUsage: Float = 0.0
    public var memoryUsage: Float = 0.0
    public var renderTime: Float = 0.0
    public var analysisTime: Float = 0.0
}

public struct VisualizationRenderData {
    public let spectrumData: [Float]
    public let waveformData: [Float]
    public let audioLevels: [String: AudioLevelData]
    public let visualizationType: VisualizationType
    public let visualizationStyle: VisualizationStyle
    public let settings: VisualizationSettings
    public let colorPalette: ColorPalette
}

// MARK: - Supporting Classes

class CircularAudioBuffer {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: 0.0, count: capacity)
    }
    
    func append(_ audioBuffer: AVAudioPCMBuffer) {
        guard let floatChannelData = audioBuffer.floatChannelData else { return }
        
        let frameCount = Int(audioBuffer.frameLength)
        let channelData = floatChannelData[0]
        
        for i in 0..<frameCount {
            buffer[writeIndex] = channelData[i]
            writeIndex = (writeIndex + 1) % capacity
        }
    }
    
    func getLatestData(length: Int) -> [Float] {
        let actualLength = min(length, capacity)
        var result = [Float](repeating: 0.0, count: actualLength)
        
        for i in 0..<actualLength {
            let index = (writeIndex - actualLength + i + capacity) % capacity
            result[i] = buffer[index]
        }
        
        return result
    }
}

class AnalysisBuffer {
    var spectrum: [Float]
    var waveform: [Float]
    var levels: AudioLevelData
    var features: AudioFeatures
    var beat: BeatInfo?
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.spectrum = Array(repeating: 0.0, count: capacity / 2)
        self.waveform = Array(repeating: 0.0, count: capacity)
        self.levels = AudioLevelData()
        self.features = AudioFeatures()
        self.beat = nil
    }
    
    func update(spectrum: [Float], waveform: [Float], levels: AudioLevelData, features: AudioFeatures, beat: BeatInfo?) {
        self.spectrum = spectrum
        self.waveform = waveform
        self.levels = levels
        self.features = features
        self.beat = beat
    }
}

class FFTAnalyzer {
    private var fftSetup: FFTSetup?
    private var configuration: FFTConfiguration = .spectrum
    private var settings: FFTSettings = .default
    
    init() {
        setupFFT()
    }
    
    deinit {
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
    
    private func setupFFT() {
        let log2n = vDSP_Length(log2(Float(settings.fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
    }
    
    func setConfiguration(_ configuration: FFTConfiguration) {
        self.configuration = configuration
    }
    
    func updateSettings(_ settings: FFTSettings) {
        self.settings = settings
        setupFFT()
    }
    
    func performFFT(_ audioData: [Float]) -> [Float] {
        guard let fftSetup = fftSetup else { return [] }
        
        let fftSize = settings.fftSize
        let halfSize = fftSize / 2
        
        // Ensure we have enough data
        let inputData = audioData.count >= fftSize ? Array(audioData[0..<fftSize]) : audioData + Array(repeating: 0.0, count: fftSize - audioData.count)
        
        // Apply window function
        var windowed = applyWindow(inputData, type: settings.windowType)
        
        // Prepare FFT buffers
        var realp = [Float](repeating: 0.0, count: halfSize)
        var imagp = [Float](repeating: 0.0, count: halfSize)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        // Perform FFT
        windowed.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &output, 1, vDSP_Length(halfSize))
            }
        }
        
        vDSP_fft_zrip(fftSetup, &output, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0.0, count: halfSize)
        vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(halfSize))
        
        // Convert to dB
        var dbMagnitudes = [Float](repeating: 0.0, count: halfSize)
        vDSP_vdbcon(magnitudes, 1, &dbMagnitudes, 1, vDSP_Length(halfSize))
        
        return dbMagnitudes
    }
    
    private func applyWindow(_ data: [Float], type: WindowType) -> [Float] {
        var windowed = [Float](repeating: 0.0, count: data.count)
        
        switch type {
        case .hann:
            vDSP_hann_window(&windowed, vDSP_Length(data.count), 0)
        case .hamming:
            vDSP_hamm_window(&windowed, vDSP_Length(data.count), 0)
        case .blackman:
            vDSP_blkman_window(&windowed, vDSP_Length(data.count), 0)
        case .rectangular:
            windowed = Array(repeating: 1.0, count: data.count)
        }
        
        vDSP_vmul(data, 1, windowed, 1, &windowed, 1, vDSP_Length(data.count))
        return windowed
    }
}

enum FFTConfiguration {
    case spectrum
    case spectrogram
}

class WaveformAnalyzer {
    private var configuration: WaveformConfiguration = .realTime
    private var settings: WaveformSettings = .default
    
    func setConfiguration(_ configuration: WaveformConfiguration) {
        self.configuration = configuration
    }
    
    func updateSettings(_ settings: WaveformSettings) {
        self.settings = settings
    }
    
    func analyzeWaveform(_ audioData: [Float]) -> [Float] {
        // Simple waveform analysis - return decimated data for visualization
        let targetSize = 1024
        let decimationFactor = max(1, audioData.count / targetSize)
        
        var result = [Float]()
        for i in stride(from: 0, to: audioData.count, by: decimationFactor) {
            result.append(audioData[i] * settings.amplitudeScale)
        }
        
        return result
    }
}

enum WaveformConfiguration {
    case realTime
    case buffered
}

class SpectrumAnalyzer {
    func findPeaks(in spectrum: [Float], count: Int) -> [SpectrumPeak] {
        var peaks = [SpectrumPeak]()
        
        // Simple peak detection
        for i in 1..<spectrum.count-1 {
            if spectrum[i] > spectrum[i-1] && spectrum[i] > spectrum[i+1] {
                let frequency = Float(i) * 22050.0 / Float(spectrum.count) // Assuming 44.1kHz sample rate
                let peak = SpectrumPeak(frequency: frequency, magnitude: spectrum[i], phase: 0.0)
                peaks.append(peak)
            }
        }
        
        // Sort by magnitude and return top peaks
        peaks.sort { $0.magnitude > $1.magnitude }
        return Array(peaks.prefix(count))
    }
}

class AudioLevelMeter {
    private var settings: LevelMeterSettings = .default
    
    func setConfiguration(_ configuration: LevelMeterConfiguration) {
        // Configure level meter
    }
    
    func updateSettings(_ settings: LevelMeterSettings) {
        self.settings = settings
    }
    
    func calculateLevels(_ audioData: [Float]) -> AudioLevelData {
        var levelData = AudioLevelData()
        
        // Calculate RMS
        let rmsSquared = audioData.reduce(0.0) { $0 + $1 * $1 } / Float(audioData.count)
        levelData.rms = sqrt(rmsSquared)
        
        // Calculate peak
        levelData.peak = audioData.max() ?? 0.0
        
        // Calculate average level
        levelData.averageLevel = audioData.reduce(0.0, +) / Float(audioData.count)
        
        // Calculate dynamic range
        let min = audioData.min() ?? 0.0
        let max = audioData.max() ?? 0.0
        levelData.dynamicRange = max - min
        
        // Count clipping
        levelData.clipCount = audioData.filter { abs($0) > 0.95 }.count
        
        levelData.timestamp = Date()
        
        return levelData
    }
}

enum LevelMeterConfiguration {
    case basic
    case detailed
}

class BeatDetector {
    private var enabled: Bool = false
    private var currentBeatInfo: BeatInfo?
    
    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }
    
    func detectBeat(_ audioData: [Float]) -> BeatInfo? {
        guard enabled else { return nil }
        
        // Simple beat detection algorithm
        // This is a placeholder - real implementation would use more sophisticated methods
        let energy = audioData.reduce(0.0) { $0 + $1 * $1 }
        let threshold: Float = 0.5
        
        if energy > threshold {
            let beatInfo = BeatInfo(
                bpm: 120.0, // Placeholder
                confidence: 0.8,
                timestamp: Date(),
                beatStrength: energy
            )
            currentBeatInfo = beatInfo
            return beatInfo
        }
        
        return nil
    }
    
    func getCurrentBeatInfo() -> BeatInfo? {
        return currentBeatInfo
    }
}

class AudioFeatureExtractor {
    func extractFeatures(_ audioData: [Float]) -> AudioFeatures {
        var features = AudioFeatures()
        
        // Extract basic audio features
        features.spectralCentroid = calculateSpectralCentroid(audioData)
        features.spectralRolloff = calculateSpectralRolloff(audioData)
        features.zeroCrossingRate = calculateZeroCrossingRate(audioData)
        features.mfccCoefficients = calculateMFCC(audioData)
        features.peakFrequencies = findPeakFrequencies(audioData)
        
        return features
    }
    
    private func calculateSpectralCentroid(_ audioData: [Float]) -> Float {
        // Placeholder implementation
        return 1000.0
    }
    
    private func calculateSpectralRolloff(_ audioData: [Float]) -> Float {
        // Placeholder implementation
        return 5000.0
    }
    
    private func calculateZeroCrossingRate(_ audioData: [Float]) -> Float {
        var crossings = 0
        for i in 1..<audioData.count {
            if (audioData[i] > 0 && audioData[i-1] <= 0) || (audioData[i] <= 0 && audioData[i-1] > 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(audioData.count)
    }
    
    private func calculateMFCC(_ audioData: [Float]) -> [Float] {
        // Placeholder implementation
        return Array(repeating: 0.0, count: 13)
    }
    
    private func findPeakFrequencies(_ audioData: [Float]) -> [Float] {
        // Placeholder implementation
        return Array(repeating: 0.0, count: 10)
    }
}

class VisualizationHistory {
    private var frames: [VisualizationFrame] = []
    private let maxFrames: Int = 3600 // 1 minute at 60fps
    
    func addFrame(spectrum: [Float], waveform: [Float], levels: AudioLevelData, timestamp: Date) {
        let frame = VisualizationFrame(spectrum: spectrum, waveform: waveform, levels: levels, timestamp: timestamp)
        frames.append(frame)
        
        if frames.count > maxFrames {
            frames.removeFirst()
        }
    }
    
    func getFrames(for duration: TimeInterval) -> [VisualizationFrame] {
        let cutoffTime = Date().addingTimeInterval(-duration)
        return frames.filter { $0.timestamp >= cutoffTime }
    }
    
    func clear() {
        frames.removeAll()
    }
}

class SmoothingFilter {
    private var settings: SmoothingSettings = .default
    
    func updateSettings(_ settings: SmoothingSettings) {
        self.settings = settings
    }
    
    func smoothSpectrum(_ spectrum: [Float]) -> [Float] {
        // Apply exponential smoothing
        let alpha = 1.0 - settings.spectrumSmoothing
        return spectrum.map { $0 * alpha + $0 * (1.0 - alpha) }
    }
    
    func smoothWaveform(_ waveform: [Float]) -> [Float] {
        // Apply exponential smoothing
        let alpha = 1.0 - settings.waveformSmoothing
        return waveform.map { $0 * alpha + $0 * (1.0 - alpha) }
    }
    
    func smoothLevels(_ levels: AudioLevelData) -> AudioLevelData {
        // Apply smoothing to audio levels
        var smoothedLevels = levels
        let alpha = 1.0 - settings.levelSmoothing
        
        smoothedLevels.rms = levels.rms * alpha + levels.rms * (1.0 - alpha)
        smoothedLevels.peak = levels.peak * alpha + levels.peak * (1.0 - alpha)
        smoothedLevels.averageLevel = levels.averageLevel * alpha + levels.averageLevel * (1.0 - alpha)
        
        return smoothedLevels
    }
}

class ColorPalette {
    private var settings: ColorSettings = .default
    
    func updateForStyle(_ style: VisualizationStyle) {
        switch style {
        case .modern:
            settings.primaryColor = "#FF6B6B"
            settings.secondaryColor = "#4ECDC4"
            settings.backgroundColor = "#2C3E50"
        case .classic:
            settings.primaryColor = "#3498DB"
            settings.secondaryColor = "#E74C3C"
            settings.backgroundColor = "#34495E"
        case .neon:
            settings.primaryColor = "#FF00FF"
            settings.secondaryColor = "#00FFFF"
            settings.backgroundColor = "#000000"
        case .minimal:
            settings.primaryColor = "#FFFFFF"
            settings.secondaryColor = "#CCCCCC"
            settings.backgroundColor = "#F8F9FA"
        case .retro:
            settings.primaryColor = "#F39C12"
            settings.secondaryColor = "#E67E22"
            settings.backgroundColor = "#8B4513"
        }
    }
    
    func updateSettings(_ settings: ColorSettings) {
        self.settings = settings
    }
}

class VisualizationRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var renderPipeline: MTLRenderPipelineState?
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        setupRenderPipeline()
    }
    
    private func setupRenderPipeline() {
        // Setup Metal render pipeline
        // This would involve creating vertex and fragment shaders
    }
    
    func render(_ renderData: VisualizationRenderData, in view: MTKView) {
        // Render visualization using Metal
        // This would involve creating command buffers and render commands
    }
    
    func updateStyle(_ style: VisualizationStyle) {
        // Update rendering style
    }
}

class VisualizationPerformanceMonitor {
    private var isMonitoring: Bool = false
    private var frameCount: Int = 0
    private var lastFrameTime: CFTimeInterval = 0
    private var targetFrameRate: Float = 60.0
    private var metrics = VisualizationPerformanceMetrics()
    
    func startMonitoring() {
        isMonitoring = true
        frameCount = 0
        lastFrameTime = CACurrentMediaTime()
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
    
    func setTargetFrameRate(_ frameRate: Float) {
        targetFrameRate = frameRate
    }
    
    func recordFrame() {
        guard isMonitoring else { return }
        
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        
        if deltaTime >= 1.0 {
            metrics.averageFrameRate = Float(frameCount) / Float(deltaTime)
            frameCount = 0
            lastFrameTime = currentTime
        }
    }
    
    func getMetrics() -> VisualizationPerformanceMetrics {
        return metrics
    }
}