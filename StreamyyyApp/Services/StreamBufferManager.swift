//
//  StreamBufferManager.swift
//  StreamyyyApp
//
//  Advanced stream buffering and caching optimization
//

import Foundation
import SwiftUI
import Combine
import AVKit
import Network

// MARK: - Stream Buffer Manager

public class StreamBufferManager: ObservableObject {
    @Published public var bufferHealth: Double = 0.0
    @Published public var bufferSize: TimeInterval = 5.0
    @Published public var cacheSize: Int64 = 0
    @Published public var isBuffering: Bool = false
    @Published public var bufferOptimizationEnabled: Bool = true
    
    private var streams: [String: StreamBuffer] = [:]
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let bufferingQueue = DispatchQueue(label: "StreamBufferManager", qos: .userInitiated)
    
    private var cacheDirectory: URL
    private var bufferTimer: Timer?
    
    public init() {
        // Setup cache directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("StreamCache")
        
        createCacheDirectory()
        loadBufferConfiguration()
        startBufferMonitoring()
    }
    
    deinit {
        bufferTimer?.invalidate()
        clearAllBuffers()
    }
    
    // MARK: - Buffer Management
    
    public func configureBuffer(for streamURL: String, quality: StreamQuality, networkCondition: NetworkCondition) {
        bufferingQueue.async { [weak self] in
            self?.setupStreamBuffer(streamURL: streamURL, quality: quality, networkCondition: networkCondition)
        }
    }
    
    private func setupStreamBuffer(streamURL: String, quality: StreamQuality, networkCondition: NetworkCondition) {
        let optimalBufferSize = calculateOptimalBufferSize(quality: quality, networkCondition: networkCondition)
        let preloadSize = calculatePreloadSize(quality: quality, networkCondition: networkCondition)
        
        let buffer = StreamBuffer(
            streamURL: streamURL,
            quality: quality,
            bufferSize: optimalBufferSize,
            preloadSize: preloadSize,
            cacheDirectory: cacheDirectory
        )
        
        streams[streamURL] = buffer
        
        DispatchQueue.main.async { [weak self] in
            self?.bufferSize = optimalBufferSize
        }
    }
    
    private func calculateOptimalBufferSize(quality: StreamQuality, networkCondition: NetworkCondition) -> TimeInterval {
        let baseBufferSize: TimeInterval = 5.0
        
        // Adjust based on quality
        let qualityMultiplier: Double = {
            switch quality {
            case .hd1080, .source:
                return 2.0
            case .hd720, .high:
                return 1.5
            case .medium:
                return 1.0
            case .low:
                return 0.8
            case .mobile:
                return 0.5
            case .auto:
                return 1.0
            }
        }()
        
        // Adjust based on network condition
        let networkMultiplier: Double = {
            switch networkCondition {
            case .ethernet:
                return 1.0
            case .wifi:
                return 1.2
            case .cellular:
                return 2.0
            case .offline, .unknown:
                return 0.5
            }
        }()
        
        return baseBufferSize * qualityMultiplier * networkMultiplier
    }
    
    private func calculatePreloadSize(quality: StreamQuality, networkCondition: NetworkCondition) -> Int64 {
        let basePreloadSize: Int64 = 1024 * 1024 // 1MB
        
        let qualityMultiplier: Double = {
            switch quality {
            case .hd1080, .source:
                return 10.0
            case .hd720, .high:
                return 5.0
            case .medium:
                return 2.0
            case .low:
                return 1.0
            case .mobile:
                return 0.5
            case .auto:
                return 3.0
            }
        }()
        
        let networkMultiplier: Double = {
            switch networkCondition {
            case .ethernet:
                return 2.0
            case .wifi:
                return 1.5
            case .cellular:
                return 0.8
            case .offline, .unknown:
                return 0.1
            }
        }()
        
        return Int64(Double(basePreloadSize) * qualityMultiplier * networkMultiplier)
    }
    
    // MARK: - Buffer Health Monitoring
    
    private func startBufferMonitoring() {
        bufferTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateBufferHealth()
        }
    }
    
    private func updateBufferHealth() {
        bufferingQueue.async { [weak self] in
            self?.calculateOverallBufferHealth()
        }
    }
    
    private func calculateOverallBufferHealth() {
        let activeStreams = streams.values.filter { $0.isActive }
        guard !activeStreams.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.bufferHealth = 0.0
                self?.isBuffering = false
            }
            return
        }
        
        let totalHealth = activeStreams.reduce(0.0) { $0 + $1.bufferHealth }
        let averageHealth = totalHealth / Double(activeStreams.count)
        
        let isCurrentlyBuffering = activeStreams.contains { $0.isBuffering }
        
        DispatchQueue.main.async { [weak self] in
            self?.bufferHealth = averageHealth
            self?.isBuffering = isCurrentlyBuffering
        }
    }
    
    // MARK: - Cache Management
    
    private func createCacheDirectory() {
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create cache directory: \(error)")
        }
    }
    
    public func clearCache() {
        bufferingQueue.async { [weak self] in
            self?.performCacheClear()
        }
    }
    
    private func performCacheClear() {
        do {
            let fileManager = FileManager.default
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in cacheContents {
                try fileManager.removeItem(at: fileURL)
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.cacheSize = 0
            }
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
    
    private func updateCacheSize() {
        bufferingQueue.async { [weak self] in
            self?.calculateCacheSize()
        }
    }
    
    private func calculateCacheSize() {
        do {
            let fileManager = FileManager.default
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            let totalSize = cacheContents.reduce(0) { total, fileURL in
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    return total + Int64(resourceValues.fileSize ?? 0)
                } catch {
                    return total
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.cacheSize = totalSize
            }
            
            // Clean up if cache is too large
            if totalSize > maxCacheSize {
                cleanupOldCacheFiles()
            }
        } catch {
            print("Failed to calculate cache size: \(error)")
        }
    }
    
    private func cleanupOldCacheFiles() {
        do {
            let fileManager = FileManager.default
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            
            // Sort by creation date (oldest first)
            let sortedFiles = cacheContents.sorted { file1, file2 in
                let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                return date1 < date2
            }
            
            // Remove oldest files until we're under the limit
            var currentSize = cacheSize
            for fileURL in sortedFiles {
                if currentSize <= maxCacheSize * 3 / 4 { // Clean to 75% of max size
                    break
                }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    
                    try fileManager.removeItem(at: fileURL)
                    currentSize -= fileSize
                } catch {
                    print("Failed to remove cache file: \(error)")
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.cacheSize = currentSize
            }
        } catch {
            print("Failed to cleanup cache: \(error)")
        }
    }
    
    // MARK: - Configuration
    
    private func loadBufferConfiguration() {
        let userDefaults = UserDefaults.standard
        bufferOptimizationEnabled = userDefaults.bool(forKey: "BufferOptimizationEnabled")
        
        if bufferOptimizationEnabled {
            // Load custom buffer settings
            let customBufferSize = userDefaults.double(forKey: "CustomBufferSize")
            if customBufferSize > 0 {
                bufferSize = customBufferSize
            }
        }
    }
    
    public func setBufferOptimization(_ enabled: Bool) {
        bufferOptimizationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "BufferOptimizationEnabled")
        
        if enabled {
            optimizeAllBuffers()
        }
    }
    
    private func optimizeAllBuffers() {
        bufferingQueue.async { [weak self] in
            self?.streams.values.forEach { buffer in
                buffer.optimizeBuffer()
            }
        }
    }
    
    // MARK: - Stream Management
    
    public func startBuffering(for streamURL: String) {
        bufferingQueue.async { [weak self] in
            self?.streams[streamURL]?.startBuffering()
        }
    }
    
    public func stopBuffering(for streamURL: String) {
        bufferingQueue.async { [weak self] in
            self?.streams[streamURL]?.stopBuffering()
        }
    }
    
    public func pauseBuffering(for streamURL: String) {
        bufferingQueue.async { [weak self] in
            self?.streams[streamURL]?.pauseBuffering()
        }
    }
    
    public func resumeBuffering(for streamURL: String) {
        bufferingQueue.async { [weak self] in
            self?.streams[streamURL]?.resumeBuffering()
        }
    }
    
    public func removeBuffer(for streamURL: String) {
        bufferingQueue.async { [weak self] in
            self?.streams[streamURL]?.cleanup()
            self?.streams.removeValue(forKey: streamURL)
        }
    }
    
    public func clearAllBuffers() {
        bufferingQueue.async { [weak self] in
            self?.streams.values.forEach { $0.cleanup() }
            self?.streams.removeAll()
        }
    }
    
    // MARK: - Buffer Statistics
    
    public func getBufferStats() -> BufferStats {
        let activeStreams = streams.values.filter { $0.isActive }
        let totalBufferSize = activeStreams.reduce(0.0) { $0 + $1.bufferSize }
        let averageBufferHealth = activeStreams.isEmpty ? 0.0 : activeStreams.reduce(0.0) { $0 + $1.bufferHealth } / Double(activeStreams.count)
        
        return BufferStats(
            activeStreams: activeStreams.count,
            totalBufferSize: totalBufferSize,
            averageBufferHealth: averageBufferHealth,
            cacheSize: cacheSize,
            isBuffering: isBuffering
        )
    }
    
    public func getBufferReport() -> BufferReport {
        return BufferReport(
            stats: getBufferStats(),
            optimization: bufferOptimizationEnabled,
            cacheDirectory: cacheDirectory.path,
            maxCacheSize: maxCacheSize,
            streamBuffers: streams.mapValues { $0.getBufferInfo() }
        )
    }
}

// MARK: - Stream Buffer

private class StreamBuffer {
    let streamURL: String
    let quality: StreamQuality
    var bufferSize: TimeInterval
    let preloadSize: Int64
    let cacheDirectory: URL
    
    var isActive: Bool = false
    var isBuffering: Bool = false
    var bufferHealth: Double = 0.0
    
    private var bufferData: Data = Data()
    private var bufferTask: URLSessionDataTask?
    private var bufferTimer: Timer?
    
    init(streamURL: String, quality: StreamQuality, bufferSize: TimeInterval, preloadSize: Int64, cacheDirectory: URL) {
        self.streamURL = streamURL
        self.quality = quality
        self.bufferSize = bufferSize
        self.preloadSize = preloadSize
        self.cacheDirectory = cacheDirectory
    }
    
    func startBuffering() {
        isActive = true
        isBuffering = true
        
        // Start buffer monitoring
        bufferTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateBufferHealth()
        }
        
        // Start preloading
        preloadData()
    }
    
    func stopBuffering() {
        isActive = false
        isBuffering = false
        
        bufferTimer?.invalidate()
        bufferTimer = nil
        
        bufferTask?.cancel()
        bufferTask = nil
    }
    
    func pauseBuffering() {
        isBuffering = false
        bufferTask?.suspend()
    }
    
    func resumeBuffering() {
        isBuffering = true
        bufferTask?.resume()
    }
    
    func optimizeBuffer() {
        // Optimize buffer based on current conditions
        if bufferHealth < 0.3 {
            // Increase buffer size
            bufferSize = min(bufferSize * 1.5, 15.0)
        } else if bufferHealth > 0.8 {
            // Decrease buffer size
            bufferSize = max(bufferSize * 0.8, 2.0)
        }
    }
    
    private func preloadData() {
        guard let url = URL(string: streamURL) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("bytes=0-\(preloadSize)", forHTTPHeaderField: "Range")
        
        bufferTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let data = data {
                self?.bufferData.append(data)
                self?.updateBufferHealth()
            }
            
            if let error = error {
                print("Buffer preload error: \(error)")
                self?.isBuffering = false
            }
        }
        
        bufferTask?.resume()
    }
    
    private func updateBufferHealth() {
        // Calculate buffer health based on data availability
        let bufferRatio = Double(bufferData.count) / Double(preloadSize)
        bufferHealth = min(1.0, bufferRatio)
        
        // Adjust buffering state
        if bufferHealth < 0.2 {
            isBuffering = true
        } else if bufferHealth > 0.8 {
            isBuffering = false
        }
    }
    
    func getBufferInfo() -> BufferInfo {
        return BufferInfo(
            streamURL: streamURL,
            quality: quality,
            bufferSize: bufferSize,
            bufferHealth: bufferHealth,
            isBuffering: isBuffering,
            dataSize: bufferData.count
        )
    }
    
    func cleanup() {
        stopBuffering()
        bufferData.removeAll()
    }
}

// MARK: - Supporting Types

public struct BufferStats {
    public let activeStreams: Int
    public let totalBufferSize: TimeInterval
    public let averageBufferHealth: Double
    public let cacheSize: Int64
    public let isBuffering: Bool
}

public struct BufferReport {
    public let stats: BufferStats
    public let optimization: Bool
    public let cacheDirectory: String
    public let maxCacheSize: Int64
    public let streamBuffers: [String: BufferInfo]
}

public struct BufferInfo {
    public let streamURL: String
    public let quality: StreamQuality
    public let bufferSize: TimeInterval
    public let bufferHealth: Double
    public let isBuffering: Bool
    public let dataSize: Int
}