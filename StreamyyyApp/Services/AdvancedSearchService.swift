//
//  AdvancedSearchService.swift
//  StreamyyyApp
//
//  Advanced search and filtering service with multi-platform support
//  Created by Claude Code on 2025-07-10
//

import Foundation
import Combine
import SwiftUI

// MARK: - Advanced Search Service

/// Comprehensive search service that provides advanced filtering, sorting, and search capabilities
/// across all supported streaming platforms with intelligent result ranking and caching
@MainActor
public class AdvancedSearchService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var searchResults: [SearchResult] = []
    @Published public private(set) var isSearching = false
    @Published public private(set) var searchError: SearchError?
    @Published public private(set) var searchStats: SearchStatistics = SearchStatistics()
    @Published public private(set) var suggestedQueries: [String] = []
    @Published public private(set) var recentSearches: [String] = []
    
    // MARK: - Services
    
    private let streamDataService: StreamDataService
    private let cacheManager: SearchCacheManager
    private let analyticsManager: SearchAnalyticsManager
    
    // MARK: - Configuration
    
    public struct Configuration {
        public let maxResults: Int
        public let cacheDuration: TimeInterval
        public let enableAutoComplete: Bool
        public let enableSearchSuggestions: Bool
        public let maxRecentSearches: Int
        public let searchTimeout: TimeInterval
        
        public init(
            maxResults: Int = 100,
            cacheDuration: TimeInterval = 300, // 5 minutes
            enableAutoComplete: Bool = true,
            enableSearchSuggestions: Bool = true,
            maxRecentSearches: Int = 20,
            searchTimeout: TimeInterval = 30.0
        ) {
            self.maxResults = maxResults
            self.cacheDuration = cacheDuration
            self.enableAutoComplete = enableAutoComplete
            self.enableSearchSuggestions = enableSearchSuggestions
            self.maxRecentSearches = maxRecentSearches
            self.searchTimeout = searchTimeout
        }
    }
    
    private let configuration: Configuration
    
    // MARK: - Search State
    
    private var currentSearchTask: Task<Void, Never>?
    private var searchHistory: [SearchHistoryItem] = []
    private let searchQueue = DispatchQueue(label: "search.queue", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init(
        streamDataService: StreamDataService,
        configuration: Configuration = Configuration()
    ) {
        self.streamDataService = streamDataService
        self.configuration = configuration
        self.cacheManager = SearchCacheManager(cacheDuration: configuration.cacheDuration)
        self.analyticsManager = SearchAnalyticsManager()
        
        loadRecentSearches()
        setupSuggestions()
    }
    
    // MARK: - Public Search Methods
    
    /// Perform comprehensive search across all platforms with advanced filtering
    public func search(
        query: String,
        filters: AdvancedSearchFilters = AdvancedSearchFilters(),
        sortBy: SearchSortOption = .relevance
    ) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        // Cancel any existing search
        currentSearchTask?.cancel()
        
        currentSearchTask = Task {
            await performSearch(query: query, filters: filters, sortBy: sortBy)
        }
        
        await currentSearchTask?.value
    }
    
    /// Get search suggestions based on partial query
    public func getSuggestions(for partialQuery: String) async -> [SearchSuggestion] {
        guard configuration.enableAutoComplete,
              partialQuery.count >= 2 else { return [] }
        
        var suggestions: [SearchSuggestion] = []
        
        // Add suggestions from search history
        let historySuggestions = searchHistory
            .filter { $0.query.lowercased().contains(partialQuery.lowercased()) }
            .prefix(5)
            .map { SearchSuggestion(text: $0.query, type: .history, metadata: ["frequency": String($0.frequency)]) }
        
        suggestions.append(contentsOf: historySuggestions)
        
        // Add category-based suggestions
        let categorySuggestions = generateCategorySuggestions(for: partialQuery)
        suggestions.append(contentsOf: categorySuggestions)
        
        // Add platform-based suggestions
        let platformSuggestions = generatePlatformSuggestions(for: partialQuery)
        suggestions.append(contentsOf: platformSuggestions)
        
        return Array(suggestions.prefix(10))
    }
    
    /// Get trending search queries
    public func getTrendingQueries() async -> [String] {
        return analyticsManager.getTrendingQueries(limit: 10)
    }
    
    /// Get search results for a specific category
    public func searchCategory(
        _ category: String,
        filters: AdvancedSearchFilters = AdvancedSearchFilters()
    ) async -> [SearchResult] {
        var categoryFilters = filters
        categoryFilters.categories = Set([category])
        
        await search(query: "", filters: categoryFilters)
        return searchResults
    }
    
    /// Get recommended searches based on user preferences
    public func getRecommendedSearches(basedOn userPreferences: UserSearchPreferences) -> [String] {
        var recommendations: [String] = []
        
        // Add category-based recommendations
        for category in userPreferences.preferredCategories {
            recommendations.append("Best \(category) streams")
            recommendations.append("Live \(category)")
        }
        
        // Add platform-based recommendations
        for platform in userPreferences.preferredPlatforms {
            recommendations.append("\(platform.displayName) trending")
            recommendations.append("Popular on \(platform.displayName)")
        }
        
        // Add language-based recommendations
        for language in userPreferences.preferredLanguages {
            recommendations.append("Streams in \(language)")
        }
        
        return Array(recommendations.prefix(8))
    }
    
    // MARK: - Search History Management
    
    /// Add query to search history
    public func addToHistory(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existingIndex = searchHistory.firstIndex(where: { $0.query == normalizedQuery }) {
            searchHistory[existingIndex].frequency += 1
            searchHistory[existingIndex].lastSearched = Date()
        } else {
            let historyItem = SearchHistoryItem(
                query: normalizedQuery,
                frequency: 1,
                lastSearched: Date()
            )
            searchHistory.append(historyItem)
        }
        
        // Sort by frequency and recency
        searchHistory.sort { first, second in
            if first.frequency != second.frequency {
                return first.frequency > second.frequency
            }
            return first.lastSearched > second.lastSearched
        }
        
        // Keep only recent searches for UI
        recentSearches = Array(searchHistory.prefix(configuration.maxRecentSearches).map { $0.query })
        saveRecentSearches()
    }
    
    /// Clear search history
    public func clearHistory() {
        searchHistory.removeAll()
        recentSearches.removeAll()
        saveRecentSearches()
    }
    
    // MARK: - Filter Presets
    
    /// Get predefined filter presets for common search scenarios
    public func getFilterPresets() -> [FilterPreset] {
        return [
            FilterPreset(
                name: "Live Streams Only",
                icon: "dot.radiowaves.left.and.right",
                filters: AdvancedSearchFilters(liveOnly: true)
            ),
            FilterPreset(
                name: "High Quality",
                icon: "4k.tv",
                filters: AdvancedSearchFilters(
                    minViewers: 1000,
                    qualityFilter: .hd1080p
                )
            ),
            FilterPreset(
                name: "Gaming",
                icon: "gamecontroller",
                filters: AdvancedSearchFilters(
                    categories: Set(["Gaming", "Games", "Esports"]),
                    liveOnly: true
                )
            ),
            FilterPreset(
                name: "Music & Entertainment",
                icon: "music.note",
                filters: AdvancedSearchFilters(
                    categories: Set(["Music", "Entertainment", "Performance"])
                )
            ),
            FilterPreset(
                name: "Educational",
                icon: "graduationcap",
                filters: AdvancedSearchFilters(
                    categories: Set(["Education", "Tutorial", "Learning"])
                )
            ),
            FilterPreset(
                name: "Popular Now",
                icon: "flame",
                filters: AdvancedSearchFilters(
                    minViewers: 500,
                    sortBy: .viewCount,
                    timeRange: .today
                )
            )
        ]
    }
    
    // MARK: - Private Methods
    
    private func performSearch(
        query: String,
        filters: AdvancedSearchFilters,
        sortBy: SearchSortOption
    ) async {
        isSearching = true
        searchError = nil
        
        let searchStartTime = Date()
        
        defer {
            isSearching = false
            let searchDuration = Date().timeIntervalSince(searchStartTime)
            analyticsManager.recordSearch(
                query: query,
                filters: filters,
                duration: searchDuration,
                resultCount: searchResults.count
            )
        }
        
        do {
            // Check cache first
            if let cachedResults = await cacheManager.getCachedResults(
                query: query,
                filters: filters,
                sortBy: sortBy
            ) {
                searchResults = cachedResults
                addToHistory(query)
                return
            }
            
            // Perform search across platforms
            let platformResults = await searchAcrossPlatforms(query: query, filters: filters)
            
            // Apply additional filtering
            let filteredResults = applyAdvancedFilters(platformResults, filters: filters)
            
            // Sort results
            let sortedResults = sortResults(filteredResults, by: sortBy, query: query)
            
            // Convert to SearchResult objects with metadata
            let searchResults = convertToSearchResults(sortedResults, query: query)
            
            // Cache results
            await cacheManager.cacheResults(
                query: query,
                filters: filters,
                sortBy: sortBy,
                results: searchResults
            )
            
            self.searchResults = Array(searchResults.prefix(configuration.maxResults))
            addToHistory(query)
            
            // Update search statistics
            updateSearchStats(query: query, resultCount: searchResults.count)
            
        } catch {
            searchError = SearchError.searchFailed(error)
            print("Search failed: \(error)")
        }
    }
    
    private func searchAcrossPlatforms(
        query: String,
        filters: AdvancedSearchFilters
    ) async -> [DiscoveredStream] {
        var allResults: [DiscoveredStream] = []
        
        // Convert to unified search filters
        let unifiedFilters = UnifiedSearchFilters(
            platforms: filters.platforms,
            categories: filters.categories,
            languages: filters.languages,
            liveOnly: filters.liveOnly,
            minViewers: filters.minViewers,
            maxViewers: filters.maxViewers,
            dateRange: convertDateRange(filters.timeRange),
            duration: convertDurationRange(filters.durationFilter),
            sortBy: convertSortOption(filters.sortBy)
        )
        
        // Search using the unified service
        await streamDataService.search(query: query, filters: unifiedFilters)
        allResults.append(contentsOf: streamDataService.searchResults)
        
        return allResults
    }
    
    private func applyAdvancedFilters(
        _ streams: [DiscoveredStream],
        filters: AdvancedSearchFilters
    ) -> [DiscoveredStream] {
        return streams.filter { stream in
            // Quality filter
            if let qualityFilter = filters.qualityFilter {
                // This would need to be implemented based on available quality data
                // For now, we'll skip this filter
            }
            
            // Time range filter
            if let timeRange = filters.timeRange {
                if !matchesTimeRange(stream, timeRange: timeRange) {
                    return false
                }
            }
            
            // Duration filter
            if let durationFilter = filters.durationFilter {
                // This would need duration data from the stream
                // For now, we'll skip this filter
            }
            
            // Exclude filter
            for excludedTerm in filters.excludeTerms {
                if stream.title.lowercased().contains(excludedTerm.lowercased()) ||
                   stream.channelName.lowercased().contains(excludedTerm.lowercased()) {
                    return false
                }
            }
            
            return true
        }
    }
    
    private func sortResults(
        _ streams: [DiscoveredStream],
        by sortOption: SearchSortOption,
        query: String
    ) -> [DiscoveredStream] {
        return streams.sorted { first, second in
            switch sortOption {
            case .relevance:
                let firstScore = calculateRelevanceScore(first, query: query)
                let secondScore = calculateRelevanceScore(second, query: query)
                return firstScore > secondScore
                
            case .viewCount:
                return first.viewerCount > second.viewerCount
                
            case .recent:
                let firstDate = first.startedAt ?? Date.distantPast
                let secondDate = second.startedAt ?? Date.distantPast
                return firstDate > secondDate
                
            case .alphabetical:
                return first.title.localizedCompare(second.title) == .orderedAscending
                
            case .platform:
                if first.platform != second.platform {
                    return first.platform.rawValue < second.platform.rawValue
                }
                return first.viewerCount > second.viewerCount
                
            case .duration:
                // Would need duration data - for now fall back to viewer count
                return first.viewerCount > second.viewerCount
            }
        }
    }
    
    private func calculateRelevanceScore(_ stream: DiscoveredStream, query: String) -> Double {
        let queryLower = query.lowercased()
        var score: Double = 0.0
        
        // Title match (highest weight)
        if stream.title.lowercased().contains(queryLower) {
            score += 1000.0
            
            // Exact match bonus
            if stream.title.lowercased() == queryLower {
                score += 500.0
            }
            
            // Beginning of title bonus
            if stream.title.lowercased().hasPrefix(queryLower) {
                score += 200.0
            }
        }
        
        // Channel name match
        if stream.channelName.lowercased().contains(queryLower) {
            score += 500.0
        }
        
        // Category match
        if let category = stream.category, category.lowercased().contains(queryLower) {
            score += 300.0
        }
        
        // Viewer count bonus (logarithmic to prevent dominance)
        score += log(Double(max(stream.viewerCount, 1))) * 10.0
        
        // Live stream bonus
        if stream.isLive {
            score += 200.0
        }
        
        // Platform popularity bonus
        switch stream.platform {
        case .twitch:
            score += 50.0
        case .youtube:
            score += 40.0
        case .rumble:
            score += 30.0
        default:
            score += 10.0
        }
        
        // Recency bonus
        if let startedAt = stream.startedAt {
            let hoursAgo = Date().timeIntervalSince(startedAt) / 3600.0
            if hoursAgo < 1 {
                score += 100.0
            } else if hoursAgo < 6 {
                score += 50.0
            } else if hoursAgo < 24 {
                score += 25.0
            }
        }
        
        return score
    }
    
    private func convertToSearchResults(
        _ streams: [DiscoveredStream],
        query: String
    ) -> [SearchResult] {
        return streams.map { stream in
            SearchResult(
                stream: stream,
                relevanceScore: calculateRelevanceScore(stream, query: query),
                searchMetadata: SearchMetadata(
                    searchQuery: query,
                    platform: stream.platform,
                    matchType: determineMatchType(stream, query: query),
                    timestamp: Date()
                )
            )
        }
    }
    
    private func determineMatchType(_ stream: DiscoveredStream, query: String) -> SearchMatchType {
        let queryLower = query.lowercased()
        
        if stream.title.lowercased() == queryLower {
            return .exact
        } else if stream.title.lowercased().contains(queryLower) {
            return .title
        } else if stream.channelName.lowercased().contains(queryLower) {
            return .channel
        } else if let category = stream.category, category.lowercased().contains(queryLower) {
            return .category
        } else {
            return .partial
        }
    }
    
    // MARK: - Utility Methods
    
    private func generateCategorySuggestions(for partialQuery: String) -> [SearchSuggestion] {
        let categories = [
            "Gaming", "Music", "Entertainment", "Sports", "News", "Education",
            "Technology", "Art", "Cooking", "Travel", "Fitness", "Comedy"
        ]
        
        return categories
            .filter { $0.lowercased().contains(partialQuery.lowercased()) }
            .map { SearchSuggestion(text: $0, type: .category) }
    }
    
    private func generatePlatformSuggestions(for partialQuery: String) -> [SearchSuggestion] {
        return Platform.allCases
            .filter { $0.displayName.lowercased().contains(partialQuery.lowercased()) }
            .map { SearchSuggestion(text: $0.displayName, type: .platform) }
    }
    
    private func matchesTimeRange(_ stream: DiscoveredStream, timeRange: TimeRangeFilter) -> Bool {
        guard let startedAt = stream.startedAt else { return true }
        
        let now = Date()
        switch timeRange {
        case .lastHour:
            return now.timeIntervalSince(startedAt) <= 3600
        case .today:
            return Calendar.current.isDate(startedAt, inSameDayAs: now)
        case .thisWeek:
            let weekAgo = now.addingTimeInterval(-7 * 24 * 3600)
            return startedAt >= weekAgo
        case .thisMonth:
            let monthAgo = now.addingTimeInterval(-30 * 24 * 3600)
            return startedAt >= monthAgo
        case .custom(let from, let to):
            return startedAt >= from && startedAt <= to
        }
    }
    
    private func convertDateRange(_ timeRange: TimeRangeFilter?) -> UnifiedSearchFilters.DateRange? {
        guard let timeRange = timeRange else { return nil }
        
        switch timeRange {
        case .today:
            return .today
        case .thisWeek:
            return .thisWeek
        case .thisMonth:
            return .thisMonth
        case .lastHour:
            return .today // Closest approximation
        case .custom(let from, let to):
            return .custom(from: from, to: to)
        }
    }
    
    private func convertDurationRange(_ duration: DurationFilter?) -> UnifiedSearchFilters.DurationRange? {
        guard let duration = duration else { return nil }
        
        switch duration {
        case .short:
            return .short
        case .medium:
            return .medium
        case .long:
            return .long
        case .any:
            return .any
        }
    }
    
    private func convertSortOption(_ sortBy: SearchSortOption?) -> UnifiedSearchFilters.SortOption {
        guard let sortBy = sortBy else { return .relevance }
        
        switch sortBy {
        case .relevance:
            return .relevance
        case .viewCount:
            return .viewCount
        case .recent:
            return .date
        case .alphabetical:
            return .alphabetical
        case .platform:
            return .platform
        case .duration:
            return .relevance // Fallback
        }
    }
    
    private func updateSearchStats(query: String, resultCount: Int) {
        searchStats.totalSearches += 1
        searchStats.totalResults += resultCount
        searchStats.averageResults = Double(searchStats.totalResults) / Double(searchStats.totalSearches)
        
        if resultCount == 0 {
            searchStats.noResultQueries.append(query)
        }
        
        searchStats.popularQueries[query, default: 0] += 1
    }
    
    private func setupSuggestions() {
        if configuration.enableSearchSuggestions {
            suggestedQueries = [
                "Gaming streams",
                "Live music",
                "Educational content",
                "Trending now",
                "Popular streamers"
            ]
        }
    }
    
    private func loadRecentSearches() {
        if let data = UserDefaults.standard.data(forKey: "RecentSearches"),
           let searches = try? JSONDecoder().decode([String].self, from: data) {
            recentSearches = searches
        }
    }
    
    private func saveRecentSearches() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: "RecentSearches")
        }
    }
}

// MARK: - Supporting Types

/// Advanced search filters with comprehensive filtering options
public struct AdvancedSearchFilters {
    public var platforms: Set<Platform>?
    public var categories: Set<String>?
    public var languages: Set<String>?
    public var liveOnly: Bool
    public var minViewers: Int?
    public var maxViewers: Int?
    public var qualityFilter: StreamQuality?
    public var timeRange: TimeRangeFilter?
    public var durationFilter: DurationFilter?
    public var excludeTerms: [String]
    public var sortBy: SearchSortOption?
    
    public init(
        platforms: Set<Platform>? = nil,
        categories: Set<String>? = nil,
        languages: Set<String>? = nil,
        liveOnly: Bool = false,
        minViewers: Int? = nil,
        maxViewers: Int? = nil,
        qualityFilter: StreamQuality? = nil,
        timeRange: TimeRangeFilter? = nil,
        durationFilter: DurationFilter? = nil,
        excludeTerms: [String] = [],
        sortBy: SearchSortOption? = nil
    ) {
        self.platforms = platforms
        self.categories = categories
        self.languages = languages
        self.liveOnly = liveOnly
        self.minViewers = minViewers
        self.maxViewers = maxViewers
        self.qualityFilter = qualityFilter
        self.timeRange = timeRange
        self.durationFilter = durationFilter
        self.excludeTerms = excludeTerms
        self.sortBy = sortBy
    }
}

/// Search result with metadata and relevance scoring
public struct SearchResult: Identifiable {
    public let id = UUID()
    public let stream: DiscoveredStream
    public let relevanceScore: Double
    public let searchMetadata: SearchMetadata
    
    public init(stream: DiscoveredStream, relevanceScore: Double, searchMetadata: SearchMetadata) {
        self.stream = stream
        self.relevanceScore = relevanceScore
        self.searchMetadata = searchMetadata
    }
}

/// Metadata about search results
public struct SearchMetadata {
    public let searchQuery: String
    public let platform: Platform
    public let matchType: SearchMatchType
    public let timestamp: Date
    
    public init(searchQuery: String, platform: Platform, matchType: SearchMatchType, timestamp: Date) {
        self.searchQuery = searchQuery
        self.platform = platform
        self.matchType = matchType
        self.timestamp = timestamp
    }
}

/// Time range filters for search
public enum TimeRangeFilter {
    case lastHour
    case today
    case thisWeek
    case thisMonth
    case custom(from: Date, to: Date)
}

/// Duration filters for content
public enum DurationFilter {
    case short      // < 4 minutes
    case medium     // 4-20 minutes
    case long       // > 20 minutes
    case any
}

/// Search sorting options
public enum SearchSortOption: String, CaseIterable {
    case relevance = "relevance"
    case viewCount = "viewCount"
    case recent = "recent"
    case alphabetical = "alphabetical"
    case platform = "platform"
    case duration = "duration"
    
    public var displayName: String {
        switch self {
        case .relevance: return "Relevance"
        case .viewCount: return "Viewer Count"
        case .recent: return "Most Recent"
        case .alphabetical: return "Alphabetical"
        case .platform: return "Platform"
        case .duration: return "Duration"
        }
    }
    
    public var icon: String {
        switch self {
        case .relevance: return "star.fill"
        case .viewCount: return "eye.fill"
        case .recent: return "clock.fill"
        case .alphabetical: return "textformat.abc"
        case .platform: return "tv.fill"
        case .duration: return "timer"
        }
    }
}

/// Types of search matches
public enum SearchMatchType {
    case exact
    case title
    case channel
    case category
    case partial
}

/// Search suggestion types
public enum SearchSuggestionType {
    case history
    case category
    case platform
    case trending
}

/// Search suggestion structure
public struct SearchSuggestion: Identifiable {
    public let id = UUID()
    public let text: String
    public let type: SearchSuggestionType
    public let metadata: [String: String]
    
    public init(text: String, type: SearchSuggestionType, metadata: [String: String] = [:]) {
        self.text = text
        self.type = type
        self.metadata = metadata
    }
}

/// Search history item
public struct SearchHistoryItem {
    public let query: String
    public var frequency: Int
    public var lastSearched: Date
    
    public init(query: String, frequency: Int, lastSearched: Date) {
        self.query = query
        self.frequency = frequency
        self.lastSearched = lastSearched
    }
}

/// User search preferences
public struct UserSearchPreferences {
    public let preferredCategories: [String]
    public let preferredPlatforms: [Platform]
    public let preferredLanguages: [String]
    public let defaultFilters: AdvancedSearchFilters
    
    public init(
        preferredCategories: [String] = [],
        preferredPlatforms: [Platform] = [],
        preferredLanguages: [String] = ["en"],
        defaultFilters: AdvancedSearchFilters = AdvancedSearchFilters()
    ) {
        self.preferredCategories = preferredCategories
        self.preferredPlatforms = preferredPlatforms
        self.preferredLanguages = preferredLanguages
        self.defaultFilters = defaultFilters
    }
}

/// Filter preset for common search scenarios
public struct FilterPreset: Identifiable {
    public let id = UUID()
    public let name: String
    public let icon: String
    public let filters: AdvancedSearchFilters
    
    public init(name: String, icon: String, filters: AdvancedSearchFilters) {
        self.name = name
        self.icon = icon
        self.filters = filters
    }
}

/// Search statistics for analytics
public struct SearchStatistics {
    public var totalSearches: Int = 0
    public var totalResults: Int = 0
    public var averageResults: Double = 0.0
    public var noResultQueries: [String] = []
    public var popularQueries: [String: Int] = [:]
    
    public var successRate: Double {
        guard totalSearches > 0 else { return 0 }
        let successfulSearches = totalSearches - noResultQueries.count
        return Double(successfulSearches) / Double(totalSearches)
    }
}

/// Search errors
public enum SearchError: Error, LocalizedError {
    case searchFailed(Error)
    case invalidQuery
    case timeout
    case tooManyRequests
    case networkUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .searchFailed(let error):
            return "Search failed: \(error.localizedDescription)"
        case .invalidQuery:
            return "Invalid search query"
        case .timeout:
            return "Search timeout"
        case .tooManyRequests:
            return "Too many search requests"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

// MARK: - Cache Manager

/// Manages search result caching
public class SearchCacheManager {
    private var cache: [String: CachedSearchResult] = [:]
    private let cacheDuration: TimeInterval
    private let queue = DispatchQueue(label: "search.cache", qos: .utility)
    
    public init(cacheDuration: TimeInterval) {
        self.cacheDuration = cacheDuration
    }
    
    public func getCachedResults(
        query: String,
        filters: AdvancedSearchFilters,
        sortBy: SearchSortOption
    ) async -> [SearchResult]? {
        let cacheKey = generateCacheKey(query: query, filters: filters, sortBy: sortBy)
        
        return await queue.sync {
            guard let cached = cache[cacheKey],
                  Date().timeIntervalSince(cached.timestamp) < cacheDuration else {
                return nil
            }
            return cached.results
        }
    }
    
    public func cacheResults(
        query: String,
        filters: AdvancedSearchFilters,
        sortBy: SearchSortOption,
        results: [SearchResult]
    ) async {
        let cacheKey = generateCacheKey(query: query, filters: filters, sortBy: sortBy)
        let cached = CachedSearchResult(results: results, timestamp: Date())
        
        await queue.async {
            self.cache[cacheKey] = cached
            self.cleanupExpiredCache()
        }
    }
    
    private func generateCacheKey(
        query: String,
        filters: AdvancedSearchFilters,
        sortBy: SearchSortOption
    ) -> String {
        let filtersData = try? JSONEncoder().encode(filters)
        let filtersHash = filtersData?.hashValue ?? 0
        return "\(query)_\(filtersHash)_\(sortBy.rawValue)"
    }
    
    private func cleanupExpiredCache() {
        let now = Date()
        cache = cache.filter { _, cached in
            now.timeIntervalSince(cached.timestamp) < cacheDuration
        }
    }
}

/// Cached search result
private struct CachedSearchResult {
    let results: [SearchResult]
    let timestamp: Date
}

// MARK: - Analytics Manager

/// Manages search analytics and insights
public class SearchAnalyticsManager {
    private var searchEvents: [SearchEvent] = []
    private let maxEvents = 1000
    
    public func recordSearch(
        query: String,
        filters: AdvancedSearchFilters,
        duration: TimeInterval,
        resultCount: Int
    ) {
        let event = SearchEvent(
            query: query,
            filters: filters,
            duration: duration,
            resultCount: resultCount,
            timestamp: Date()
        )
        
        searchEvents.append(event)
        
        // Keep only recent events
        if searchEvents.count > maxEvents {
            searchEvents.removeFirst(searchEvents.count - maxEvents)
        }
    }
    
    public func getTrendingQueries(limit: Int) -> [String] {
        let now = Date()
        let recentEvents = searchEvents.filter { now.timeIntervalSince($0.timestamp) < 24 * 3600 }
        
        let queryFrequency = recentEvents.reduce(into: [String: Int]()) { result, event in
            result[event.query, default: 0] += 1
        }
        
        return queryFrequency
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    public func getSearchAnalytics() -> SearchAnalytics {
        let now = Date()
        let recentEvents = searchEvents.filter { now.timeIntervalSince($0.timestamp) < 24 * 3600 }
        
        let avgDuration = recentEvents.isEmpty ? 0 : recentEvents.map { $0.duration }.reduce(0, +) / Double(recentEvents.count)
        let avgResults = recentEvents.isEmpty ? 0 : recentEvents.map { Double($0.resultCount) }.reduce(0, +) / Double(recentEvents.count)
        
        return SearchAnalytics(
            totalSearches: recentEvents.count,
            averageDuration: avgDuration,
            averageResults: avgResults,
            popularQueries: getTrendingQueries(limit: 10)
        )
    }
}

/// Search event for analytics
private struct SearchEvent {
    let query: String
    let filters: AdvancedSearchFilters
    let duration: TimeInterval
    let resultCount: Int
    let timestamp: Date
}

/// Search analytics data
public struct SearchAnalytics {
    public let totalSearches: Int
    public let averageDuration: TimeInterval
    public let averageResults: Double
    public let popularQueries: [String]
}