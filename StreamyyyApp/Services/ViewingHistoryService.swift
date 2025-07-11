//
//  ViewingHistoryService.swift
//  StreamyyyApp
//
//  Service for tracking and managing viewing history with real persistence
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
public class ViewingHistoryService: ObservableObject {
    public static let shared = ViewingHistoryService()
    
    // MARK: - Published Properties
    @Published public var viewingHistory: [ViewingHistory] = []
    @Published public var isLoading = false
    @Published public var error: ViewingHistoryError?
    @Published public var currentSession: ViewingSession?
    @Published public var totalWatchTime: TimeInterval = 0
    @Published public var filterOption: ViewingHistoryFilter = .all
    @Published public var sortOption: ViewingHistorySortOption = .recentFirst
    @Published public var searchQuery = ""
    
    // MARK: - Statistics
    @Published public var dailyWatchTime: TimeInterval = 0
    @Published public var weeklyWatchTime: TimeInterval = 0
    @Published public var monthlyWatchTime: TimeInterval = 0
    @Published public var favoriteStreamers: [String] = []
    @Published public var favoritePlatforms: [Platform] = []
    @Published public var averageSessionLength: TimeInterval = 0
    @Published public var completionRate: Double = 0.0
    
    // MARK: - Private Properties
    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private let userDefaults = UserDefaults.standard
    private let maxHistoryEntries = 10000
    private let sessionUpdateInterval: TimeInterval = 10.0
    
    private init() {
        setupObservers()
        loadStatistics()
    }
    
    // MARK: - Setup Methods
    public func setModelContext(_ modelContext: ModelContext) {
        self.modelContext = modelContext
        loadViewingHistory()
    }
    
    private func setupObservers() {
        // Search query observer
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.filterHistory()
            }
            .store(in: &cancellables)
        
        // Filter observer
        $filterOption
            .sink { [weak self] _ in
                self?.filterHistory()
            }
            .store(in: &cancellables)
        
        // Sort observer
        $sortOption
            .sink { [weak self] _ in
                self?.sortHistory()
            }
            .store(in: &cancellables)
        
        // App lifecycle observers
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.pauseCurrentSession()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.resumeCurrentSession()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Start tracking a new viewing session
    public func startSession(
        streamId: String,
        streamTitle: String,
        streamURL: String,
        platform: Platform,
        streamerName: String? = nil,
        thumbnailURL: String? = nil,
        category: String? = nil,
        wasLive: Bool = true,
        viewerCount: Int? = nil
    ) {
        // End any existing session
        endCurrentSession()
        
        let session = ViewingSession(
            streamId: streamId,
            streamTitle: streamTitle,
            streamURL: streamURL,
            platform: platform,
            streamerName: streamerName,
            thumbnailURL: thumbnailURL,
            category: category,
            wasLive: wasLive,
            viewerCount: viewerCount
        )
        
        currentSession = session
        
        // Start tracking timer
        startSessionTimer()
        
        print("Started viewing session for: \(streamTitle)")
    }
    
    /// Update current session with viewing data
    public func updateSession(
        viewDuration: TimeInterval? = nil,
        totalDuration: TimeInterval? = nil,
        quality: StreamQuality? = nil,
        viewerCount: Int? = nil
    ) {
        guard var session = currentSession else { return }
        
        if let duration = viewDuration {
            session.viewDuration = duration
        }
        
        if let total = totalDuration {
            session.totalStreamDuration = total
            session.updateWatchPercentage()
        }
        
        if let quality = quality {
            session.watchQuality = quality
        }
        
        if let count = viewerCount {
            session.viewerCountAtView = count
        }
        
        session.lastUpdated = Date()
        currentSession = session
    }
    
    /// End current session and save to history
    public func endCurrentSession(reason: ViewingExitReason = .userChoice) {
        guard let session = currentSession else { return }
        
        stopSessionTimer()
        
        // Create history entry
        let history = ViewingHistory(
            streamId: session.streamId,
            streamTitle: session.streamTitle,
            streamURL: session.streamURL,
            platform: session.platform,
            streamerName: session.streamerName,
            thumbnailURL: session.thumbnailURL,
            category: session.category,
            viewedAt: session.startTime,
            viewDuration: session.viewDuration,
            watchQuality: session.watchQuality,
            sessionId: session.id,
            wasLive: session.wasLive
        )
        
        history.totalStreamDuration = session.totalStreamDuration
        history.watchPercentage = session.watchPercentage
        history.exitReason = reason
        history.viewerCountAtView = session.viewerCountAtView
        history.isCompleted = session.watchPercentage >= 95.0
        
        // Save to persistence
        Task {
            await saveViewingHistory(history)
        }
        
        currentSession = nil
        
        print("Ended viewing session: \(session.streamTitle) - Duration: \(history.displayDuration)")
    }
    
    /// Pause current session
    public func pauseCurrentSession() {
        stopSessionTimer()
        
        if var session = currentSession {
            session.isPaused = true
            session.pausedAt = Date()
            currentSession = session
        }
    }
    
    /// Resume current session
    public func resumeCurrentSession() {
        if var session = currentSession, session.isPaused {
            session.isPaused = false
            
            // Add paused time to total paused duration
            if let pausedAt = session.pausedAt {
                session.totalPausedDuration += Date().timeIntervalSince(pausedAt)
            }
            
            session.pausedAt = nil
            currentSession = session
            
            startSessionTimer()
        }
    }
    
    /// Add a rating to a history entry
    public func addRating(to historyId: String, rating: Int) async {
        guard let index = viewingHistory.firstIndex(where: { $0.id == historyId }) else { return }
        
        viewingHistory[index].addRating(rating)
        await updateViewingHistory(viewingHistory[index])
    }
    
    /// Add notes to a history entry
    public func addNotes(to historyId: String, notes: String) async {
        guard let index = viewingHistory.firstIndex(where: { $0.id == historyId }) else { return }
        
        viewingHistory[index].updateNotes(notes)
        await updateViewingHistory(viewingHistory[index])
    }
    
    /// Delete a history entry
    public func deleteHistory(_ historyId: String) async {
        guard let modelContext = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<ViewingHistory>(
                predicate: #Predicate { $0.id == historyId }
            )
            
            if let history = try modelContext.fetch(descriptor).first {
                modelContext.delete(history)
                try modelContext.save()
                
                viewingHistory.removeAll { $0.id == historyId }
                await updateStatistics()
            }
        } catch {
            self.error = .deleteFailed(error)
        }
    }
    
    /// Clear all viewing history
    public func clearAllHistory() async {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        
        do {
            let descriptor = FetchDescriptor<ViewingHistory>()
            let allHistory = try modelContext.fetch(descriptor)
            
            for history in allHistory {
                modelContext.delete(history)
            }
            
            try modelContext.save()
            viewingHistory.removeAll()
            
            // Reset statistics
            totalWatchTime = 0
            dailyWatchTime = 0
            weeklyWatchTime = 0
            monthlyWatchTime = 0
            averageSessionLength = 0
            completionRate = 0.0
            favoriteStreamers.removeAll()
            favoritePlatforms.removeAll()
            
            saveStatistics()
            
        } catch {
            self.error = .clearFailed(error)
        }
        
        isLoading = false
    }
    
    /// Get viewing history for a specific date range
    public func getHistory(from startDate: Date, to endDate: Date) -> [ViewingHistory] {
        return viewingHistory.filter { history in
            history.viewedAt >= startDate && history.viewedAt <= endDate
        }
    }
    
    /// Get viewing history for a specific platform
    public func getHistory(for platform: Platform) -> [ViewingHistory] {
        return viewingHistory.filter { $0.platform == platform }
    }
    
    /// Get viewing history for a specific streamer
    public func getHistory(for streamer: String) -> [ViewingHistory] {
        return viewingHistory.filter { 
            $0.streamerName?.lowercased() == streamer.lowercased() 
        }
    }
    
    /// Export viewing history
    public func exportHistory(format: ExportFormat = .json) -> Data? {
        switch format {
        case .json:
            return exportAsJSON()
        case .csv:
            return exportAsCSV()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadViewingHistory() {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        
        do {
            let descriptor = FetchDescriptor<ViewingHistory>(
                sortBy: [SortDescriptor(\.viewedAt, order: .reverse)]
            )
            viewingHistory = try modelContext.fetch(descriptor)
            
            // Limit history entries
            if viewingHistory.count > maxHistoryEntries {
                let excess = viewingHistory.suffix(viewingHistory.count - maxHistoryEntries)
                for history in excess {
                    modelContext.delete(history)
                }
                viewingHistory = Array(viewingHistory.prefix(maxHistoryEntries))
                try modelContext.save()
            }
            
            Task {
                await updateStatistics()
            }
            
        } catch {
            self.error = .loadFailed(error)
        }
        
        isLoading = false
    }
    
    private func saveViewingHistory(_ history: ViewingHistory) async {
        guard let modelContext = modelContext else { return }
        
        do {
            modelContext.insert(history)
            try modelContext.save()
            
            viewingHistory.insert(history, at: 0)
            
            // Limit history entries
            if viewingHistory.count > maxHistoryEntries {
                if let lastHistory = viewingHistory.last {
                    modelContext.delete(lastHistory)
                    try modelContext.save()
                }
                viewingHistory = Array(viewingHistory.prefix(maxHistoryEntries))
            }
            
            await updateStatistics()
            
        } catch {
            self.error = .saveFailed(error)
        }
    }
    
    private func updateViewingHistory(_ history: ViewingHistory) async {
        guard let modelContext = modelContext else { return }
        
        do {
            try modelContext.save()
            
            if let index = viewingHistory.firstIndex(where: { $0.id == history.id }) {
                viewingHistory[index] = history
            }
            
        } catch {
            self.error = .updateFailed(error)
        }
    }
    
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: sessionUpdateInterval, repeats: true) { [weak self] _ in
            self?.updateCurrentSession()
        }
    }
    
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    private func updateCurrentSession() {
        guard var session = currentSession, !session.isPaused else { return }
        
        session.viewDuration = Date().timeIntervalSince(session.startTime) - session.totalPausedDuration
        session.lastUpdated = Date()
        session.updateWatchPercentage()
        
        currentSession = session
    }
    
    private func updateStatistics() async {
        let now = Date()
        let calendar = Calendar.current
        
        // Calculate total watch time
        totalWatchTime = viewingHistory.reduce(0) { $0 + $1.viewDuration }
        
        // Calculate daily watch time
        let startOfDay = calendar.startOfDay(for: now)
        let todayHistory = viewingHistory.filter { $0.viewedAt >= startOfDay }
        dailyWatchTime = todayHistory.reduce(0) { $0 + $1.viewDuration }
        
        // Calculate weekly watch time
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let weekHistory = viewingHistory.filter { $0.viewedAt >= startOfWeek }
        weeklyWatchTime = weekHistory.reduce(0) { $0 + $1.viewDuration }
        
        // Calculate monthly watch time
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let monthHistory = viewingHistory.filter { $0.viewedAt >= startOfMonth }
        monthlyWatchTime = monthHistory.reduce(0) { $0 + $1.viewDuration }
        
        // Calculate average session length
        if !viewingHistory.isEmpty {
            averageSessionLength = totalWatchTime / Double(viewingHistory.count)
        }
        
        // Calculate completion rate
        let completedSessions = viewingHistory.filter { $0.isCompleted }.count
        if !viewingHistory.isEmpty {
            completionRate = Double(completedSessions) / Double(viewingHistory.count) * 100.0
        }
        
        // Calculate favorite streamers
        let streamerCounts = Dictionary(grouping: viewingHistory.compactMap { $0.streamerName }) { $0 }
            .mapValues { $0.count }
        favoriteStreamers = Array(streamerCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key })
        
        // Calculate favorite platforms
        let platformCounts = Dictionary(grouping: viewingHistory.map { $0.platform }) { $0 }
            .mapValues { $0.count }
        favoritePlatforms = Array(platformCounts.sorted { $0.value > $1.value }.prefix(3).map { $0.key })
        
        saveStatistics()
    }
    
    private func filterHistory() {
        // Implementation would filter viewingHistory based on current filters
        // This is a simplified version
        sortHistory()
    }
    
    private func sortHistory() {
        viewingHistory.sort { lhs, rhs in
            switch sortOption {
            case .recentFirst:
                return lhs.viewedAt > rhs.viewedAt
            case .oldestFirst:
                return lhs.viewedAt < rhs.viewedAt
            case .longestDuration:
                return lhs.viewDuration > rhs.viewDuration
            case .shortestDuration:
                return lhs.viewDuration < rhs.viewDuration
            case .highestRated:
                return (lhs.rating ?? 0) > (rhs.rating ?? 0)
            case .mostCompleted:
                return lhs.watchPercentage > rhs.watchPercentage
            case .byPlatform:
                return lhs.platform.displayName < rhs.platform.displayName
            case .byStreamer:
                return (lhs.streamerName ?? "") < (rhs.streamerName ?? "")
            }
        }
    }
    
    private func loadStatistics() {
        totalWatchTime = userDefaults.double(forKey: "totalWatchTime")
        dailyWatchTime = userDefaults.double(forKey: "dailyWatchTime")
        weeklyWatchTime = userDefaults.double(forKey: "weeklyWatchTime")
        monthlyWatchTime = userDefaults.double(forKey: "monthlyWatchTime")
        averageSessionLength = userDefaults.double(forKey: "averageSessionLength")
        completionRate = userDefaults.double(forKey: "completionRate")
        favoriteStreamers = userDefaults.stringArray(forKey: "favoriteStreamers") ?? []
        
        if let platformNames = userDefaults.stringArray(forKey: "favoritePlatforms") {
            favoritePlatforms = platformNames.compactMap { Platform(rawValue: $0) }
        }
    }
    
    private func saveStatistics() {
        userDefaults.set(totalWatchTime, forKey: "totalWatchTime")
        userDefaults.set(dailyWatchTime, forKey: "dailyWatchTime")
        userDefaults.set(weeklyWatchTime, forKey: "weeklyWatchTime")
        userDefaults.set(monthlyWatchTime, forKey: "monthlyWatchTime")
        userDefaults.set(averageSessionLength, forKey: "averageSessionLength")
        userDefaults.set(completionRate, forKey: "completionRate")
        userDefaults.set(favoriteStreamers, forKey: "favoriteStreamers")
        userDefaults.set(favoritePlatforms.map { $0.rawValue }, forKey: "favoritePlatforms")
    }
    
    private func exportAsJSON() -> Data? {
        let exportData = viewingHistory.map { $0.export() }
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    private func exportAsCSV() -> Data? {
        var csv = "Date,Stream Title,Streamer,Platform,Duration,Watch Percentage,Rating,Completed\n"
        
        for history in viewingHistory {
            let row = [
                history.exactTime,
                history.streamTitle,
                history.streamerName ?? "",
                history.platform.displayName,
                history.displayDuration,
                history.displayWatchPercentage,
                String(history.rating ?? 0),
                String(history.isCompleted)
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv.data(using: .utf8)
    }
}

// MARK: - Supporting Types

public struct ViewingSession {
    public let id = UUID().uuidString
    public let streamId: String
    public let streamTitle: String
    public let streamURL: String
    public let platform: Platform
    public let streamerName: String?
    public let thumbnailURL: String?
    public let category: String?
    public let startTime = Date()
    public let wasLive: Bool
    public var viewDuration: TimeInterval = 0
    public var totalStreamDuration: TimeInterval?
    public var watchPercentage: Double = 0.0
    public var watchQuality: StreamQuality = .medium
    public var viewerCountAtView: Int?
    public var isPaused = false
    public var pausedAt: Date?
    public var totalPausedDuration: TimeInterval = 0
    public var lastUpdated = Date()
    
    public mutating func updateWatchPercentage() {
        if let totalDuration = totalStreamDuration, totalDuration > 0 {
            watchPercentage = min(100.0, (viewDuration / totalDuration) * 100.0)
        }
    }
}

public enum ExportFormat {
    case json
    case csv
}

public enum ViewingHistoryError: Error, LocalizedError {
    case loadFailed(Error)
    case saveFailed(Error)
    case updateFailed(Error)
    case deleteFailed(Error)
    case clearFailed(Error)
    case sessionError(String)
    case exportError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let error):
            return "Failed to load viewing history: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save viewing history: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update viewing history: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete viewing history: \(error.localizedDescription)"
        case .clearFailed(let error):
            return "Failed to clear viewing history: \(error.localizedDescription)"
        case .sessionError(let message):
            return "Session error: \(message)"
        case .exportError(let error):
            return "Export failed: \(error.localizedDescription)"
        }
    }
}