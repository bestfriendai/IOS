//
//  QualityPresets.swift
//  StreamyyyApp
//
//  User-customizable quality presets and preferences
//

import Foundation
import SwiftUI

// MARK: - Quality Presets

public class QualityPresets: ObservableObject {
    @Published public var userPreferences: UserQualityPreferences
    @Published public var customPresets: [QualityPreset] = []
    @Published public var currentPreset: QualityPreset?
    
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "UserQualityPreferences"
    private let customPresetsKey = "CustomQualityPresets"
    
    public init() {
        self.userPreferences = loadPreferences()
        self.customPresets = loadCustomPresets()
        self.currentPreset = findPresetByName(userPreferences.selectedPreset)
    }
    
    // MARK: - User Preferences
    
    public func loadPreferences() -> UserQualityPreferences {
        if let data = userDefaults.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode(UserQualityPreferences.self, from: data) {
            return preferences
        }
        
        return UserQualityPreferences()
    }
    
    public func savePreferences(_ preferences: UserQualityPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            userDefaults.set(data, forKey: preferencesKey)
        }
        
        userPreferences = preferences
    }
    
    public func updatePreferences(_ update: (inout UserQualityPreferences) -> Void) {
        var preferences = userPreferences
        update(&preferences)
        savePreferences(preferences)
    }
    
    // MARK: - Custom Presets
    
    public func loadCustomPresets() -> [QualityPreset] {
        if let data = userDefaults.data(forKey: customPresetsKey),
           let presets = try? JSONDecoder().decode([QualityPreset].self, from: data) {
            return presets
        }
        
        return defaultPresets()
    }
    
    public func saveCustomPresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            userDefaults.set(data, forKey: customPresetsKey)
        }
    }
    
    public func addCustomPreset(_ preset: QualityPreset) {
        // Check if preset with same name exists
        if let existingIndex = customPresets.firstIndex(where: { $0.name == preset.name }) {
            customPresets[existingIndex] = preset
        } else {
            customPresets.append(preset)
        }
        
        saveCustomPresets()
    }
    
    public func removeCustomPreset(_ preset: QualityPreset) {
        customPresets.removeAll { $0.id == preset.id }
        saveCustomPresets()
    }
    
    public func findPresetByName(_ name: String) -> QualityPreset? {
        let allPresets = defaultPresets() + customPresets
        return allPresets.first { $0.name == name }
    }
    
    // MARK: - Default Presets
    
    private func defaultPresets() -> [QualityPreset] {
        return [
            QualityPreset(
                name: "Auto",
                description: "Automatically adjusts quality based on connection",
                defaultQuality: .auto,
                adaptiveQuality: true,
                maxQuality: .hd1080,
                minQuality: .mobile,
                batteryOptimization: true,
                thermalOptimization: true,
                networkOptimization: true,
                maxConcurrentStreams: 4,
                bufferSize: .medium,
                frameRateLimit: nil,
                isDefault: true
            ),
            
            QualityPreset(
                name: "High Quality",
                description: "Best quality experience for fast connections",
                defaultQuality: .hd1080,
                adaptiveQuality: false,
                maxQuality: .hd1080,
                minQuality: .hd720,
                batteryOptimization: false,
                thermalOptimization: false,
                networkOptimization: false,
                maxConcurrentStreams: 2,
                bufferSize: .large,
                frameRateLimit: nil,
                isDefault: true
            ),
            
            QualityPreset(
                name: "Balanced",
                description: "Good quality with reasonable resource usage",
                defaultQuality: .hd720,
                adaptiveQuality: true,
                maxQuality: .hd720,
                minQuality: .medium,
                batteryOptimization: true,
                thermalOptimization: true,
                networkOptimization: true,
                maxConcurrentStreams: 3,
                bufferSize: .medium,
                frameRateLimit: 30,
                isDefault: true
            ),
            
            QualityPreset(
                name: "Battery Saver",
                description: "Optimized for extended battery life",
                defaultQuality: .medium,
                adaptiveQuality: true,
                maxQuality: .medium,
                minQuality: .mobile,
                batteryOptimization: true,
                thermalOptimization: true,
                networkOptimization: true,
                maxConcurrentStreams: 1,
                bufferSize: .small,
                frameRateLimit: 24,
                isDefault: true
            ),
            
            QualityPreset(
                name: "Data Saver",
                description: "Minimal data usage for cellular connections",
                defaultQuality: .low,
                adaptiveQuality: true,
                maxQuality: .medium,
                minQuality: .mobile,
                batteryOptimization: true,
                thermalOptimization: true,
                networkOptimization: true,
                maxConcurrentStreams: 1,
                bufferSize: .small,
                frameRateLimit: 24,
                isDefault: true
            ),
            
            QualityPreset(
                name: "Gaming",
                description: "Low latency for gaming streams",
                defaultQuality: .hd720,
                adaptiveQuality: false,
                maxQuality: .hd720,
                minQuality: .hd720,
                batteryOptimization: false,
                thermalOptimization: false,
                networkOptimization: false,
                maxConcurrentStreams: 1,
                bufferSize: .small,
                frameRateLimit: 60,
                isDefault: true
            )
        ]
    }
    
    // MARK: - Preset Management
    
    public func selectPreset(_ preset: QualityPreset) {
        currentPreset = preset
        
        updatePreferences { preferences in
            preferences.selectedPreset = preset.name
            preferences.adaptiveQuality = preset.adaptiveQuality
            preferences.defaultQuality = preset.defaultQuality
            preferences.maxQuality = preset.maxQuality
            preferences.minQuality = preset.minQuality
            preferences.batteryOptimization = preset.batteryOptimization
            preferences.thermalOptimization = preset.thermalOptimization
            preferences.networkOptimization = preset.networkOptimization
            preferences.maxConcurrentStreams = preset.maxConcurrentStreams
            preferences.bufferSize = preset.bufferSize
            preferences.frameRateLimit = preset.frameRateLimit
        }
    }
    
    public func getAllPresets() -> [QualityPreset] {
        return defaultPresets() + customPresets
    }
    
    public func getPresetForCondition(_ condition: PresetCondition) -> QualityPreset? {
        switch condition {
        case .cellular:
            return findPresetByName("Data Saver")
        case .lowBattery:
            return findPresetByName("Battery Saver")
        case .highPerformance:
            return findPresetByName("High Quality")
        case .gaming:
            return findPresetByName("Gaming")
        case .balanced:
            return findPresetByName("Balanced")
        }
    }
    
    // MARK: - Preset Creation
    
    public func createPresetFromCurrentSettings(
        name: String,
        description: String,
        preferences: UserQualityPreferences
    ) -> QualityPreset {
        return QualityPreset(
            name: name,
            description: description,
            defaultQuality: preferences.defaultQuality,
            adaptiveQuality: preferences.adaptiveQuality,
            maxQuality: preferences.maxQuality,
            minQuality: preferences.minQuality,
            batteryOptimization: preferences.batteryOptimization,
            thermalOptimization: preferences.thermalOptimization,
            networkOptimization: preferences.networkOptimization,
            maxConcurrentStreams: preferences.maxConcurrentStreams,
            bufferSize: preferences.bufferSize,
            frameRateLimit: preferences.frameRateLimit,
            isDefault: false
        )
    }
    
    // MARK: - Preset Recommendations
    
    public func getRecommendedPreset(
        networkCondition: NetworkCondition,
        batteryLevel: Float,
        thermalState: ThermalState,
        isCharging: Bool
    ) -> QualityPreset? {
        
        // Emergency conditions
        if batteryLevel < 0.1 && !isCharging {
            return findPresetByName("Battery Saver")
        }
        
        if thermalState == .critical {
            return findPresetByName("Battery Saver")
        }
        
        // Network-based recommendations
        switch networkCondition {
        case .cellular:
            return findPresetByName("Data Saver")
        case .wifi:
            if batteryLevel < 0.3 && !isCharging {
                return findPresetByName("Battery Saver")
            } else {
                return findPresetByName("Balanced")
            }
        case .ethernet:
            return findPresetByName("High Quality")
        case .offline, .unknown:
            return findPresetByName("Auto")
        }
    }
    
    // MARK: - Preset Validation
    
    public func validatePreset(_ preset: QualityPreset) -> [PresetValidationError] {
        var errors: [PresetValidationError] = []
        
        // Check name
        if preset.name.isEmpty {
            errors.append(.emptyName)
        }
        
        // Check quality consistency
        if preset.maxQuality.bitrate < preset.minQuality.bitrate {
            errors.append(.invalidQualityRange)
        }
        
        // Check concurrent streams
        if preset.maxConcurrentStreams < 1 || preset.maxConcurrentStreams > 10 {
            errors.append(.invalidConcurrentStreams)
        }
        
        // Check frame rate
        if let frameRate = preset.frameRateLimit, frameRate < 1 || frameRate > 120 {
            errors.append(.invalidFrameRate)
        }
        
        return errors
    }
    
    // MARK: - Export/Import
    
    public func exportPresets() -> Data? {
        let exportData = PresetExportData(
            presets: customPresets,
            preferences: userPreferences,
            exportDate: Date(),
            version: "1.0"
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    public func importPresets(from data: Data) -> Bool {
        guard let exportData = try? JSONDecoder().decode(PresetExportData.self, from: data) else {
            return false
        }
        
        // Add imported presets
        for preset in exportData.presets {
            addCustomPreset(preset)
        }
        
        return true
    }
}

// MARK: - Supporting Types

public struct UserQualityPreferences: Codable {
    public var selectedPreset: String = "Auto"
    public var adaptiveQuality: Bool = true
    public var defaultQuality: StreamQuality = .auto
    public var maxQuality: StreamQuality = .hd1080
    public var minQuality: StreamQuality = .mobile
    public var batteryOptimization: Bool = true
    public var thermalOptimization: Bool = true
    public var networkOptimization: Bool = true
    public var maxConcurrentStreams: Int = 4
    public var bufferSize: BufferSize = .medium
    public var frameRateLimit: Int? = nil
    public var autoSwitchPresets: Bool = true
    public var showQualityIndicator: Bool = true
    public var notifyQualityChanges: Bool = false
    
    public init() {}
}

public struct QualityPreset: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String
    public let defaultQuality: StreamQuality
    public let adaptiveQuality: Bool
    public let maxQuality: StreamQuality
    public let minQuality: StreamQuality
    public let batteryOptimization: Bool
    public let thermalOptimization: Bool
    public let networkOptimization: Bool
    public let maxConcurrentStreams: Int
    public let bufferSize: BufferSize
    public let frameRateLimit: Int?
    public let isDefault: Bool
    public let createdAt: Date
    
    public init(
        name: String,
        description: String,
        defaultQuality: StreamQuality,
        adaptiveQuality: Bool,
        maxQuality: StreamQuality,
        minQuality: StreamQuality,
        batteryOptimization: Bool,
        thermalOptimization: Bool,
        networkOptimization: Bool,
        maxConcurrentStreams: Int,
        bufferSize: BufferSize,
        frameRateLimit: Int?,
        isDefault: Bool
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.defaultQuality = defaultQuality
        self.adaptiveQuality = adaptiveQuality
        self.maxQuality = maxQuality
        self.minQuality = minQuality
        self.batteryOptimization = batteryOptimization
        self.thermalOptimization = thermalOptimization
        self.networkOptimization = networkOptimization
        self.maxConcurrentStreams = maxConcurrentStreams
        self.bufferSize = bufferSize
        self.frameRateLimit = frameRateLimit
        self.isDefault = isDefault
        self.createdAt = Date()
    }
}

public enum BufferSize: String, Codable, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
    
    public var bufferDuration: TimeInterval {
        switch self {
        case .small: return 2.0
        case .medium: return 5.0
        case .large: return 10.0
        }
    }
}

public enum PresetCondition: String, CaseIterable {
    case cellular = "cellular"
    case lowBattery = "low_battery"
    case highPerformance = "high_performance"
    case gaming = "gaming"
    case balanced = "balanced"
    
    public var displayName: String {
        switch self {
        case .cellular: return "Cellular Connection"
        case .lowBattery: return "Low Battery"
        case .highPerformance: return "High Performance"
        case .gaming: return "Gaming"
        case .balanced: return "Balanced"
        }
    }
}

public enum PresetValidationError: Error, LocalizedError {
    case emptyName
    case invalidQualityRange
    case invalidConcurrentStreams
    case invalidFrameRate
    
    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Preset name cannot be empty"
        case .invalidQualityRange:
            return "Max quality must be higher than min quality"
        case .invalidConcurrentStreams:
            return "Concurrent streams must be between 1 and 10"
        case .invalidFrameRate:
            return "Frame rate must be between 1 and 120"
        }
    }
}

public struct PresetExportData: Codable {
    public let presets: [QualityPreset]
    public let preferences: UserQualityPreferences
    public let exportDate: Date
    public let version: String
}