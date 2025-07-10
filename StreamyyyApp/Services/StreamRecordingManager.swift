//
//  StreamRecordingManager.swift
//  StreamyyyApp
//
//  Advanced stream recording and highlight capture system
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import AVFoundation
import ReplayKit
import Combine

// MARK: - Stream Recording Manager
@MainActor
class StreamRecordingManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var recordingStreams: Set<String> = []
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingQuality: RecordingQuality = .high
    @Published var highlightCaptures: [HighlightCapture] = []
    @Published var recordingProgress: [String: RecordingProgress] = [:]
    @Published var availableStorage: Int64 = 0
    @Published var recordingSettings: RecordingSettings = RecordingSettings()
    
    // MARK: - Private Properties
    private var recordingTimer: Timer?
    private var recordingSessions: [String: RecordingSession] = [:]
    private let replayKitRecorder = RPScreenRecorder.shared()
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    init() {
        setupRecordingEnvironment()
        checkAvailableStorage()
        loadRecordingSettings()
    }
    
    // MARK: - Recording Control
    func startRecording(for streamId: String) {
        guard !recordingStreams.contains(streamId) else { return }
        
        requestRecordingPermissions { [weak self] granted in
            if granted {
                self?.beginRecording(for: streamId)
            } else {
                print("Recording permission denied")
            }
        }
    }
    
    func stopRecording(for streamId: String) {
        guard recordingStreams.contains(streamId) else { return }
        
        endRecording(for: streamId)
    }
    
    func stopAllRecordings() {
        let streamIds = Array(recordingStreams)
        for streamId in streamIds {
            stopRecording(for: streamId)
        }
    }
    
    func pauseRecording(for streamId: String) {
        guard let session = recordingSessions[streamId] else { return }
        session.pause()
        updateRecordingProgress(for: streamId)
    }
    
    func resumeRecording(for streamId: String) {
        guard let session = recordingSessions[streamId] else { return }
        session.resume()
        updateRecordingProgress(for: streamId)
    }
    
    // MARK: - Highlight Capture
    func captureHighlight(for streamId: String, duration: TimeInterval = 30.0, title: String? = nil) {
        guard recordingStreams.contains(streamId) else {
            // Start temporary recording for highlight
            startTemporaryRecording(for: streamId, duration: duration)
            return
        }
        
        let highlight = HighlightCapture(
            id: UUID().uuidString,
            streamId: streamId,
            title: title ?? "Highlight \(Date().formatted())",
            timestamp: Date(),
            duration: duration,
            quality: recordingQuality
        )
        
        highlightCaptures.append(highlight)
        processHighlightCapture(highlight)
    }
    
    func saveHighlight(_ highlight: HighlightCapture) {
        // Save highlight to photo library or files
        exportHighlight(highlight) { [weak self] result in
            switch result {
            case .success(let url):
                print("Highlight saved to: \(url)")
                self?.showHighlightSavedNotification(highlight)
            case .failure(let error):
                print("Failed to save highlight: \(error)")
            }
        }
    }
    
    func deleteHighlight(_ highlight: HighlightCapture) {
        highlightCaptures.removeAll { $0.id == highlight.id }
        deleteHighlightFile(highlight)
    }
    
    // MARK: - Recording Settings
    func updateRecordingQuality(_ quality: RecordingQuality) {
        recordingQuality = quality
        recordingSettings.quality = quality
        saveRecordingSettings()
        
        // Update active recordings
        for (streamId, session) in recordingSessions {
            session.updateQuality(quality)
        }
    }
    
    func updateRecordingSettings(_ settings: RecordingSettings) {
        recordingSettings = settings
        saveRecordingSettings()
    }
    
    // MARK: - Storage Management
    func checkAvailableStorage() {
        do {
            let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let resourceValues = try documentsURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            availableStorage = resourceValues.volumeAvailableCapacity ?? 0
        } catch {
            print("Failed to check available storage: \(error)")
            availableStorage = 0
        }
    }
    
    func getRecordingStorageUsage() -> Int64 {
        let recordingsURL = getRecordingsDirectory()
        return calculateDirectorySize(recordingsURL)
    }
    
    func cleanupOldRecordings() {
        let recordingsURL = getRecordingsDirectory()
        let maxAge: TimeInterval = recordingSettings.maxRecordingAge
        
        do {
            let files = try fileManager.contentsOfDirectory(at: recordingsURL, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in files {
                let resourceValues = try fileURL.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = resourceValues.creationDate,
                   Date().timeIntervalSince(creationDate) > maxAge {
                    try fileManager.removeItem(at: fileURL)
                    print("Deleted old recording: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Failed to cleanup old recordings: \(error)")
        }
    }
    
    // MARK: - Recording Analytics
    func getRecordingStatistics() -> RecordingStatistics {
        let totalRecordings = highlightCaptures.count
        let totalDuration = highlightCaptures.reduce(0) { $0 + $1.duration }
        let averageDuration = totalRecordings > 0 ? totalDuration / Double(totalRecordings) : 0
        let storageUsed = getRecordingStorageUsage()
        
        return RecordingStatistics(
            totalRecordings: totalRecordings,
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            storageUsed: storageUsed,
            favoriteHighlights: highlightCaptures.filter { $0.isFavorite }.count
        )
    }
    
    // MARK: - Private Methods
    private func setupRecordingEnvironment() {
        // Configure ReplayKit
        replayKitRecorder.delegate = self
        
        // Create recordings directory
        createRecordingsDirectory()
        
        // Setup recording timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingDurations()
        }
    }
    
    private func requestRecordingPermissions(completion: @escaping (Bool) -> Void) {
        // Check microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { microphoneGranted in
            DispatchQueue.main.async {
                if microphoneGranted {
                    // Check screen recording permission (ReplayKit)
                    if self.replayKitRecorder.isAvailable {
                        completion(true)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }
    }
    
    private func beginRecording(for streamId: String) {
        let session = RecordingSession(
            streamId: streamId,
            quality: recordingQuality,
            settings: recordingSettings
        )
        
        recordingSessions[streamId] = session
        recordingStreams.insert(streamId)
        
        session.start { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Recording started for stream: \(streamId)")
                    self?.updateRecordingProgress(for: streamId)
                case .failure(let error):
                    print("Failed to start recording: \(error)")
                    self?.recordingStreams.remove(streamId)
                    self?.recordingSessions.removeValue(forKey: streamId)
                }
            }
        }
        
        // Update global recording state
        isRecording = !recordingStreams.isEmpty
    }
    
    private func endRecording(for streamId: String) {
        guard let session = recordingSessions[streamId] else { return }
        
        session.stop { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileURL):
                    print("Recording saved to: \(fileURL)")
                    self?.processCompletedRecording(streamId: streamId, fileURL: fileURL)
                case .failure(let error):
                    print("Failed to stop recording: \(error)")
                }
                
                self?.recordingStreams.remove(streamId)
                self?.recordingSessions.removeValue(forKey: streamId)
                self?.recordingProgress.removeValue(forKey: streamId)
                
                // Update global recording state
                self?.isRecording = !(self?.recordingStreams.isEmpty ?? true)
            }
        }
    }
    
    private func startTemporaryRecording(for streamId: String, duration: TimeInterval) {
        // Start a temporary recording just for highlight capture
        startRecording(for: streamId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.stopRecording(for: streamId)
        }
    }
    
    private func processHighlightCapture(_ highlight: HighlightCapture) {
        // Process the highlight capture
        // This could involve trimming the recording, applying effects, etc.
        
        DispatchQueue.global(qos: .background).async {
            // Simulate processing
            Thread.sleep(forTimeInterval: 2.0)
            
            DispatchQueue.main.async {
                // Mark highlight as processed
                if let index = self.highlightCaptures.firstIndex(where: { $0.id == highlight.id }) {
                    self.highlightCaptures[index].isProcessed = true
                }
            }
        }
    }
    
    private func exportHighlight(_ highlight: HighlightCapture, completion: @escaping (Result<URL, Error>) -> Void) {
        // Export highlight to files or photo library
        let outputURL = getHighlightOutputURL(for: highlight)
        
        DispatchQueue.global(qos: .background).async {
            // Simulate export process
            Thread.sleep(forTimeInterval: 1.0)
            
            DispatchQueue.main.async {
                completion(.success(outputURL))
            }
        }
    }
    
    private func updateRecordingDurations() {
        for (streamId, session) in recordingSessions {
            recordingDuration = session.currentDuration
            updateRecordingProgress(for: streamId)
        }
    }
    
    private func updateRecordingProgress(for streamId: String) {
        guard let session = recordingSessions[streamId] else { return }
        
        let progress = RecordingProgress(
            streamId: streamId,
            duration: session.currentDuration,
            fileSize: session.currentFileSize,
            isActive: session.isRecording,
            isPaused: session.isPaused
        )
        
        recordingProgress[streamId] = progress
    }
    
    private func processCompletedRecording(streamId: String, fileURL: URL) {
        // Process completed recording
        // This could involve generating thumbnails, metadata, etc.
        
        let recording = CompletedRecording(
            id: UUID().uuidString,
            streamId: streamId,
            fileURL: fileURL,
            duration: recordingDuration,
            quality: recordingQuality,
            timestamp: Date()
        )
        
        // Save recording metadata
        saveRecordingMetadata(recording)
    }
    
    private func createRecordingsDirectory() {
        let recordingsURL = getRecordingsDirectory()
        try? fileManager.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
    }
    
    private func getRecordingsDirectory() -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("Recordings")
    }
    
    private func getHighlightOutputURL(for highlight: HighlightCapture) -> URL {
        let recordingsURL = getRecordingsDirectory()
        let filename = "highlight_\(highlight.id)_\(Date().timeIntervalSince1970).mp4"
        return recordingsURL.appendingPathComponent(filename)
    }
    
    private func calculateDirectorySize(_ directoryURL: URL) -> Int64 {
        var totalSize: Int64 = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.fileSizeKey])
            
            for fileURL in files {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        } catch {
            print("Failed to calculate directory size: \(error)")
        }
        
        return totalSize
    }
    
    private func deleteHighlightFile(_ highlight: HighlightCapture) {
        let fileURL = getHighlightOutputURL(for: highlight)
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func showHighlightSavedNotification(_ highlight: HighlightCapture) {
        // Show notification that highlight was saved
        NotificationCenter.default.post(
            name: .highlightSaved,
            object: highlight
        )
    }
    
    private func saveRecordingMetadata(_ recording: CompletedRecording) {
        // Save recording metadata to local storage
        let metadataURL = getRecordingsDirectory().appendingPathComponent("metadata.json")
        
        do {
            var metadata: [CompletedRecording] = []
            
            if fileManager.fileExists(atPath: metadataURL.path) {
                let data = try Data(contentsOf: metadataURL)
                metadata = try JSONDecoder().decode([CompletedRecording].self, from: data)
            }
            
            metadata.append(recording)
            
            let updatedData = try JSONEncoder().encode(metadata)
            try updatedData.write(to: metadataURL)
        } catch {
            print("Failed to save recording metadata: \(error)")
        }
    }
    
    private func loadRecordingSettings() {
        // Load recording settings from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "recording_settings"),
           let settings = try? JSONDecoder().decode(RecordingSettings.self, from: data) {
            recordingSettings = settings
        }
    }
    
    private func saveRecordingSettings() {
        // Save recording settings to UserDefaults
        if let data = try? JSONEncoder().encode(recordingSettings) {
            UserDefaults.standard.set(data, forKey: "recording_settings")
        }
    }
}

// MARK: - RPScreenRecorderDelegate
extension StreamRecordingManager: RPScreenRecorderDelegate {
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: Error?) {
        if let error = error {
            print("Screen recording stopped with error: \(error)")
        }
    }
}

// MARK: - Recording Session
class RecordingSession {
    let streamId: String
    let quality: RecordingQuality
    let settings: RecordingSettings
    
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var currentDuration: TimeInterval = 0
    private(set) var currentFileSize: Int64 = 0
    private(set) var startTime: Date?
    
    private var recordingTimer: Timer?
    private var outputURL: URL?
    private let replayKitRecorder = RPScreenRecorder.shared()
    
    init(streamId: String, quality: RecordingQuality, settings: RecordingSettings) {
        self.streamId = streamId
        self.quality = quality
        self.settings = settings
    }
    
    func start(completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isRecording else {
            completion(.failure(RecordingError.alreadyRecording))
            return
        }
        
        outputURL = generateOutputURL()
        startTime = Date()
        
        replayKitRecorder.startRecording { [weak self] error in
            if let error = error {
                completion(.failure(error))
            } else {
                self?.isRecording = true
                self?.startDurationTimer()
                completion(.success(()))
            }
        }
    }
    
    func stop(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else {
            completion(.failure(RecordingError.notRecording))
            return
        }
        
        replayKitRecorder.stopRecording { [weak self] previewViewController, error in
            self?.isRecording = false
            self?.stopDurationTimer()
            
            if let error = error {
                completion(.failure(error))
            } else if let outputURL = self?.outputURL {
                completion(.success(outputURL))
            } else {
                completion(.failure(RecordingError.noOutputURL))
            }
        }
    }
    
    func pause() {
        isPaused = true
        stopDurationTimer()
    }
    
    func resume() {
        isPaused = false
        startDurationTimer()
    }
    
    func updateQuality(_ quality: RecordingQuality) {
        // Update recording quality if possible
        // This might require stopping and restarting the recording
    }
    
    private func startDurationTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDuration()
        }
    }
    
    private func stopDurationTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func updateDuration() {
        guard let startTime = startTime, !isPaused else { return }
        currentDuration = Date().timeIntervalSince(startTime)
        updateFileSize()
    }
    
    private func updateFileSize() {
        guard let outputURL = outputURL else { return }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            currentFileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            // File might not exist yet
            currentFileSize = 0
        }
    }
    
    private func generateOutputURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsURL = documentsURL.appendingPathComponent("Recordings")
        let filename = "recording_\(streamId)_\(Date().timeIntervalSince1970).mp4"
        return recordingsURL.appendingPathComponent(filename)
    }
}

// MARK: - Data Models

public enum RecordingQuality: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
    
    public var displayName: String {
        switch self {
        case .low: return "Low (480p)"
        case .medium: return "Medium (720p)"
        case .high: return "High (1080p)"
        case .ultra: return "Ultra (4K)"
        }
    }
    
    public var resolution: CGSize {
        switch self {
        case .low: return CGSize(width: 854, height: 480)
        case .medium: return CGSize(width: 1280, height: 720)
        case .high: return CGSize(width: 1920, height: 1080)
        case .ultra: return CGSize(width: 3840, height: 2160)
        }
    }
    
    public var bitrate: Int {
        switch self {
        case .low: return 2500
        case .medium: return 5000
        case .high: return 8000
        case .ultra: return 20000
        }
    }
}

public struct RecordingSettings: Codable {
    public var quality: RecordingQuality = .high
    public var includeAudio: Bool = true
    public var includeMicrophone: Bool = false
    public var autoSaveHighlights: Bool = true
    public var maxRecordingDuration: TimeInterval = 3600 // 1 hour
    public var maxRecordingAge: TimeInterval = 2592000 // 30 days
    public var compressionEnabled: Bool = true
    public var watermarkEnabled: Bool = false
    public var watermarkText: String = "Streamyyy"
    
    public init() {}
}

public struct HighlightCapture: Identifiable, Codable {
    public let id: String
    public let streamId: String
    public var title: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let quality: RecordingQuality
    public var isProcessed: Bool = false
    public var isFavorite: Bool = false
    public var tags: [String] = []
    public var thumbnailURL: URL?
    public var fileURL: URL?
    
    public init(id: String, streamId: String, title: String, timestamp: Date, duration: TimeInterval, quality: RecordingQuality) {
        self.id = id
        self.streamId = streamId
        self.title = title
        self.timestamp = timestamp
        self.duration = duration
        self.quality = quality
    }
}

public struct RecordingProgress {
    public let streamId: String
    public let duration: TimeInterval
    public let fileSize: Int64
    public let isActive: Bool
    public let isPaused: Bool
    
    public var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        return formatter.string(from: duration) ?? "00:00:00"
    }
    
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

public struct CompletedRecording: Codable {
    public let id: String
    public let streamId: String
    public let fileURL: URL
    public let duration: TimeInterval
    public let quality: RecordingQuality
    public let timestamp: Date
    
    public init(id: String, streamId: String, fileURL: URL, duration: TimeInterval, quality: RecordingQuality, timestamp: Date) {
        self.id = id
        self.streamId = streamId
        self.fileURL = fileURL
        self.duration = duration
        self.quality = quality
        self.timestamp = timestamp
    }
}

public struct RecordingStatistics {
    public let totalRecordings: Int
    public let totalDuration: TimeInterval
    public let averageDuration: TimeInterval
    public let storageUsed: Int64
    public let favoriteHighlights: Int
    
    public var formattedTotalDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalDuration) ?? "0m"
    }
    
    public var formattedStorageUsed: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: storageUsed)
    }
}

// MARK: - Recording Errors
public enum RecordingError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case permissionDenied
    case insufficientStorage
    case noOutputURL
    case qualityNotSupported
    
    public var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No active recording to stop"
        case .permissionDenied:
            return "Recording permission denied"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .noOutputURL:
            return "No output URL specified"
        case .qualityNotSupported:
            return "Recording quality not supported"
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let highlightSaved = Notification.Name("highlightSaved")
    static let recordingStarted = Notification.Name("recordingStarted")
    static let recordingStopped = Notification.Name("recordingStopped")
}