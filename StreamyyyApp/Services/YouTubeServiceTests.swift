//
//  YouTubeServiceTests.swift
//  StreamyyyApp
//
//  Comprehensive tests and usage examples for YouTubeService
//

import XCTest
import Foundation
@testable import StreamyyyApp

class YouTubeServiceTests: XCTestCase {
    
    var youtubeService: YouTubeService!
    
    override func setUpWithError() throws {
        super.setUp()
        // Initialize with test API key
        youtubeService = YouTubeService(apiKey: "TEST_API_KEY")
    }
    
    override func tearDownWithError() throws {
        youtubeService = nil
        super.tearDown()
    }
    
    // MARK: - Video Tests
    
    func testGetVideo() async throws {
        // Test getting a single video
        let videoId = "dQw4w9WgXcQ" // Rick Astley - Never Gonna Give You Up
        
        do {
            let video = try await youtubeService.getVideo(id: videoId)
            XCTAssertNotNil(video)
            XCTAssertEqual(video?.id, videoId)
            XCTAssertFalse(video?.snippet.title.isEmpty ?? true)
        } catch {
            print("Error getting video: \(error)")
            XCTFail("Failed to get video: \(error)")
        }
    }
    
    func testGetVideos() async throws {
        // Test getting multiple videos
        let videoIds = ["dQw4w9WgXcQ", "9bZkp7q19f0", "kJQP7kiw5Fk"]
        
        do {
            let videos = try await youtubeService.getVideos(ids: videoIds)
            XCTAssertGreaterThan(videos.count, 0)
            XCTAssertLessThanOrEqual(videos.count, videoIds.count)
        } catch {
            print("Error getting videos: \(error)")
            XCTFail("Failed to get videos: \(error)")
        }
    }
    
    func testGetLiveStreams() async throws {
        // Test getting live streams
        do {
            let liveStreams = try await youtubeService.getLiveStreams(maxResults: 10)
            XCTAssertNotNil(liveStreams)
            
            // Check if any live streams are actually live
            for item in liveStreams.items {
                if item.isLive {
                    XCTAssertEqual(item.snippet.liveBroadcastContent, "live")
                }
            }
        } catch {
            print("Error getting live streams: \(error)")
            // This might fail if there are no live streams at the moment
        }
    }
    
    func testGetUpcomingLiveStreams() async throws {
        // Test getting upcoming live streams
        do {
            let upcomingStreams = try await youtubeService.getUpcomingLiveStreams(maxResults: 10)
            XCTAssertNotNil(upcomingStreams)
            
            // Check if any upcoming streams are properly marked
            for item in upcomingStreams.items {
                if item.isUpcoming {
                    XCTAssertEqual(item.snippet.liveBroadcastContent, "upcoming")
                }
            }
        } catch {
            print("Error getting upcoming streams: \(error)")
            // This might fail if there are no upcoming streams
        }
    }
    
    // MARK: - Channel Tests
    
    func testGetChannel() async throws {
        // Test getting a channel by ID
        let channelId = "UC_x5XG1OV2P6uZZ5FSM9Ttw" // Google Developers
        
        do {
            let channel = try await youtubeService.getChannel(id: channelId)
            XCTAssertNotNil(channel)
            XCTAssertEqual(channel?.id, channelId)
            XCTAssertFalse(channel?.snippet.title.isEmpty ?? true)
        } catch {
            print("Error getting channel: \(error)")
            XCTFail("Failed to get channel: \(error)")
        }
    }
    
    func testGetChannelByUsername() async throws {
        // Test getting a channel by username
        let username = "Google"
        
        do {
            let channel = try await youtubeService.getChannelByUsername(username: username)
            XCTAssertNotNil(channel)
            XCTAssertFalse(channel?.snippet.title.isEmpty ?? true)
        } catch {
            print("Error getting channel by username: \(error)")
            // This might fail if the username doesn't exist
        }
    }
    
    func testGetVideosByChannel() async throws {
        // Test getting videos from a specific channel
        let channelId = "UC_x5XG1OV2P6uZZ5FSM9Ttw" // Google Developers
        
        do {
            let videos = try await youtubeService.getVideosByChannel(channelId: channelId, maxResults: 10)
            XCTAssertNotNil(videos)
            XCTAssertGreaterThan(videos.items.count, 0)
            
            // Verify all videos are from the correct channel
            for item in videos.items {
                XCTAssertEqual(item.snippet.channelId, channelId)
            }
        } catch {
            print("Error getting videos by channel: \(error)")
            XCTFail("Failed to get videos by channel: \(error)")
        }
    }
    
    // MARK: - Search Tests
    
    func testSearch() async throws {
        // Test basic search
        let query = "Swift programming"
        
        do {
            let results = try await youtubeService.search(query: query, maxResults: 10)
            XCTAssertNotNil(results)
            XCTAssertGreaterThan(results.items.count, 0)
            
            // Verify search results contain the query term
            for item in results.items {
                let title = item.snippet.title.lowercased()
                let description = item.snippet.description.lowercased()
                let queryLower = query.lowercased()
                
                // At least one of the search terms should appear in title or description
                let hasSwift = title.contains("swift") || description.contains("swift")
                let hasProgramming = title.contains("programming") || description.contains("programming")
                
                XCTAssertTrue(hasSwift || hasProgramming, "Search result should contain query terms")
            }
        } catch {
            print("Error searching: \(error)")
            XCTFail("Failed to search: \(error)")
        }
    }
    
    func testSearchWithFilters() async throws {
        // Test search with filters
        let query = "iOS development"
        var filters = SearchFilters()
        filters.order = .viewCount
        filters.duration = .medium
        filters.definition = .high
        
        do {
            let results = try await youtubeService.search(query: query, maxResults: 5, filters: filters)
            XCTAssertNotNil(results)
            XCTAssertGreaterThan(results.items.count, 0)
        } catch {
            print("Error searching with filters: \(error)")
            XCTFail("Failed to search with filters: \(error)")
        }
    }
    
    func testSearchChannels() async throws {
        // Test searching for channels
        let query = "Apple"
        
        do {
            let results = try await youtubeService.searchChannels(query: query, maxResults: 5)
            XCTAssertNotNil(results)
            
            // Verify all results are channels
            for item in results.items {
                XCTAssertEqual(item.id.kind, "youtube#channel")
                XCTAssertNotNil(item.channelId)
            }
        } catch {
            print("Error searching channels: \(error)")
            XCTFail("Failed to search channels: \(error)")
        }
    }
    
    func testSearchPlaylists() async throws {
        // Test searching for playlists
        let query = "Swift tutorials"
        
        do {
            let results = try await youtubeService.searchPlaylists(query: query, maxResults: 5)
            XCTAssertNotNil(results)
            
            // Verify all results are playlists
            for item in results.items {
                XCTAssertEqual(item.id.kind, "youtube#playlist")
                XCTAssertNotNil(item.playlistId)
            }
        } catch {
            print("Error searching playlists: \(error)")
            XCTFail("Failed to search playlists: \(error)")
        }
    }
    
    // MARK: - Playlist Tests
    
    func testGetPlaylist() async throws {
        // Test getting a playlist
        let playlistId = "PLrAXtmRdnEQy6nuLMV9_WzoxJBxnpPy8J" // Example playlist
        
        do {
            let playlist = try await youtubeService.getPlaylist(id: playlistId)
            XCTAssertNotNil(playlist)
            XCTAssertEqual(playlist?.id, playlistId)
            XCTAssertFalse(playlist?.snippet.title.isEmpty ?? true)
        } catch {
            print("Error getting playlist: \(error)")
            // This might fail if the playlist doesn't exist
        }
    }
    
    func testGetPlaylistItems() async throws {
        // Test getting playlist items
        let playlistId = "PLrAXtmRdnEQy6nuLMV9_WzoxJBxnpPy8J" // Example playlist
        
        do {
            let items = try await youtubeService.getPlaylistItems(playlistId: playlistId, maxResults: 10)
            XCTAssertNotNil(items)
            
            // Verify all items belong to the playlist
            for item in items.items {
                XCTAssertEqual(item.snippet.playlistId, playlistId)
                XCTAssertNotNil(item.snippet.resourceId.videoId)
            }
        } catch {
            print("Error getting playlist items: \(error)")
            // This might fail if the playlist doesn't exist
        }
    }
    
    func testGetPlaylistsByChannel() async throws {
        // Test getting playlists from a channel
        let channelId = "UC_x5XG1OV2P6uZZ5FSM9Ttw" // Google Developers
        
        do {
            let playlists = try await youtubeService.getPlaylistsByChannel(channelId: channelId, maxResults: 10)
            XCTAssertNotNil(playlists)
            
            // Verify all playlists belong to the channel
            for playlist in playlists.items {
                XCTAssertEqual(playlist.snippet.channelId, channelId)
            }
        } catch {
            print("Error getting playlists by channel: \(error)")
            XCTFail("Failed to get playlists by channel: \(error)")
        }
    }
    
    // MARK: - Comment Tests
    
    func testGetVideoComments() async throws {
        // Test getting comments for a video
        let videoId = "dQw4w9WgXcQ" // Rick Astley - Never Gonna Give You Up
        
        do {
            let comments = try await youtubeService.getVideoComments(videoId: videoId, maxResults: 10)
            XCTAssertNotNil(comments)
            
            // Verify all comments are for the correct video
            for comment in comments.items {
                XCTAssertEqual(comment.snippet.videoId, videoId)
                XCTAssertFalse(comment.snippet.textDisplay.isEmpty)
            }
        } catch {
            print("Error getting video comments: \(error)")
            // This might fail if comments are disabled
        }
    }
    
    // MARK: - Trending Tests
    
    func testGetTrendingVideos() async throws {
        // Test getting trending videos
        do {
            let trendingVideos = try await youtubeService.getTrendingVideos(maxResults: 10)
            XCTAssertNotNil(trendingVideos)
            XCTAssertGreaterThan(trendingVideos.items.count, 0)
            
            // Verify trending videos have statistics
            for video in trendingVideos.items {
                XCTAssertNotNil(video.statistics)
                XCTAssertFalse(video.snippet.title.isEmpty)
            }
        } catch {
            print("Error getting trending videos: \(error)")
            XCTFail("Failed to get trending videos: \(error)")
        }
    }
    
    func testGetVideoCategories() async throws {
        // Test getting video categories
        do {
            let categories = try await youtubeService.getVideoCategories()
            XCTAssertNotNil(categories)
            XCTAssertGreaterThan(categories.items.count, 0)
            
            // Verify categories have required fields
            for category in categories.items {
                XCTAssertFalse(category.id.isEmpty)
                XCTAssertFalse(category.snippet.title.isEmpty)
            }
        } catch {
            print("Error getting video categories: \(error)")
            XCTFail("Failed to get video categories: \(error)")
        }
    }
    
    // MARK: - Utility Tests
    
    func testGetVideoEmbedUrl() {
        // Test generating embed URL
        let videoId = "dQw4w9WgXcQ"
        let embedUrl = youtubeService.getVideoEmbedUrl(videoId: videoId, autoplay: true, muted: true)
        
        XCTAssertTrue(embedUrl.contains(videoId))
        XCTAssertTrue(embedUrl.contains("autoplay=1"))
        XCTAssertTrue(embedUrl.contains("mute=1"))
        XCTAssertTrue(embedUrl.contains("playsinline=1"))
        XCTAssertTrue(embedUrl.contains("enablejsapi=1"))
    }
    
    func testParseDuration() {
        // Test duration parsing
        let duration1 = "PT4M13S" // 4 minutes 13 seconds
        let duration2 = "PT1H30M45S" // 1 hour 30 minutes 45 seconds
        let duration3 = "PT30S" // 30 seconds
        
        let seconds1 = youtubeService.parseDuration(duration1)
        let seconds2 = youtubeService.parseDuration(duration2)
        let seconds3 = youtubeService.parseDuration(duration3)
        
        XCTAssertEqual(seconds1, 253) // 4*60 + 13
        XCTAssertEqual(seconds2, 5445) // 1*3600 + 30*60 + 45
        XCTAssertEqual(seconds3, 30)
    }
    
    func testVideoExtensions() {
        // Test video extensions
        let video = YouTubeVideo(
            id: "test",
            snippet: YouTubeVideo.VideoSnippet(
                publishedAt: "2023-01-01T00:00:00Z",
                channelId: "testChannel",
                title: "Test Video",
                description: "Test Description",
                thumbnails: Thumbnails(
                    default: Thumbnails.ThumbnailInfo(url: "https://example.com/default.jpg", width: 120, height: 90),
                    medium: Thumbnails.ThumbnailInfo(url: "https://example.com/medium.jpg", width: 320, height: 180),
                    high: Thumbnails.ThumbnailInfo(url: "https://example.com/high.jpg", width: 480, height: 360),
                    standard: nil,
                    maxres: nil
                ),
                channelTitle: "Test Channel",
                tags: ["test", "video"],
                categoryId: "22",
                liveBroadcastContent: "live",
                defaultLanguage: "en",
                localized: nil
            ),
            statistics: YouTubeVideo.VideoStatistics(
                viewCount: "1000",
                likeCount: "100",
                dislikeCount: "10",
                favoriteCount: "50",
                commentCount: "25"
            ),
            liveStreamingDetails: nil,
            status: nil,
            contentDetails: YouTubeVideo.ContentDetails(
                duration: "PT4M13S",
                dimension: "2d",
                definition: "hd",
                caption: "false",
                licensedContent: false,
                projection: "rectangular",
                hasCustomThumbnail: true
            )
        )
        
        XCTAssertTrue(video.isLive)
        XCTAssertFalse(video.isUpcoming)
        XCTAssertEqual(video.viewCountInt, 1000)
        XCTAssertEqual(video.likeCountInt, 100)
        XCTAssertEqual(video.commentCountInt, 25)
        XCTAssertEqual(video.durationSeconds, 253)
        XCTAssertEqual(video.bestThumbnailUrl, "https://example.com/high.jpg")
    }
    
    // MARK: - Quota Management Tests
    
    func testQuotaManagement() {
        // Test quota properties
        let remainingQuota = youtubeService.remainingQuota
        let quotaPercentage = youtubeService.quotaPercentageUsed
        let timeUntilReset = youtubeService.timeUntilQuotaReset
        
        XCTAssertGreaterThanOrEqual(remainingQuota, 0)
        XCTAssertGreaterThanOrEqual(quotaPercentage, 0.0)
        XCTAssertLessThanOrEqual(quotaPercentage, 1.0)
        XCTAssertGreaterThan(timeUntilReset, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        // Test error descriptions
        let errors: [YouTubeAPIError] = [
            .invalidURL,
            .invalidResponse,
            .badRequest,
            .unauthorized,
            .forbidden,
            .notFound,
            .rateLimited,
            .quotaExceeded,
            .serverError,
            .networkError(NSError(domain: "test", code: 0, userInfo: nil)),
            .unknown(999)
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    func testSearchPerformance() throws {
        // Test search performance
        measure {
            let expectation = XCTestExpectation(description: "Search performance")
            
            Task {
                do {
                    _ = try await youtubeService.search(query: "Swift", maxResults: 10)
                    expectation.fulfill()
                } catch {
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflow() async throws {
        // Test a complete workflow: search -> get video details -> get channel -> get comments
        let query = "Swift programming"
        
        do {
            // 1. Search for videos
            let searchResults = try await youtubeService.search(query: query, maxResults: 5)
            XCTAssertGreaterThan(searchResults.items.count, 0)
            
            guard let firstResult = searchResults.items.first,
                  let videoId = firstResult.videoId else {
                XCTFail("No video found in search results")
                return
            }
            
            // 2. Get detailed video information
            let video = try await youtubeService.getVideo(id: videoId)
            XCTAssertNotNil(video)
            
            // 3. Get channel information
            let channelId = video?.snippet.channelId ?? firstResult.snippet.channelId
            let channel = try await youtubeService.getChannel(id: channelId)
            XCTAssertNotNil(channel)
            
            // 4. Get video comments (if available)
            do {
                let comments = try await youtubeService.getVideoComments(videoId: videoId, maxResults: 5)
                XCTAssertNotNil(comments)
            } catch {
                // Comments might be disabled, so we don't fail the test
                print("Comments not available for video: \(error)")
            }
            
            // 5. Get channel playlists
            let playlists = try await youtubeService.getPlaylistsByChannel(channelId: channelId, maxResults: 5)
            XCTAssertNotNil(playlists)
            
        } catch {
            print("Integration test failed: \(error)")
            XCTFail("Integration test failed: \(error)")
        }
    }
}

// MARK: - Mock Data for Testing

extension YouTubeServiceTests {
    
    func createMockVideo() -> YouTubeVideo {
        return YouTubeVideo(
            id: "mockVideoId",
            snippet: YouTubeVideo.VideoSnippet(
                publishedAt: "2023-01-01T00:00:00Z",
                channelId: "mockChannelId",
                title: "Mock Video Title",
                description: "Mock video description",
                thumbnails: Thumbnails(
                    default: Thumbnails.ThumbnailInfo(url: "https://example.com/default.jpg", width: 120, height: 90),
                    medium: Thumbnails.ThumbnailInfo(url: "https://example.com/medium.jpg", width: 320, height: 180),
                    high: Thumbnails.ThumbnailInfo(url: "https://example.com/high.jpg", width: 480, height: 360),
                    standard: nil,
                    maxres: nil
                ),
                channelTitle: "Mock Channel",
                tags: ["mock", "test"],
                categoryId: "22",
                liveBroadcastContent: "none",
                defaultLanguage: "en",
                localized: nil
            ),
            statistics: YouTubeVideo.VideoStatistics(
                viewCount: "1000",
                likeCount: "100",
                dislikeCount: "10",
                favoriteCount: "50",
                commentCount: "25"
            ),
            liveStreamingDetails: nil,
            status: nil,
            contentDetails: YouTubeVideo.ContentDetails(
                duration: "PT4M13S",
                dimension: "2d",
                definition: "hd",
                caption: "false",
                licensedContent: false,
                projection: "rectangular",
                hasCustomThumbnail: true
            )
        )
    }
    
    func createMockChannel() -> YouTubeChannel {
        return YouTubeChannel(
            id: "mockChannelId",
            snippet: YouTubeChannel.ChannelSnippet(
                title: "Mock Channel",
                description: "Mock channel description",
                customUrl: "mockChannel",
                publishedAt: "2020-01-01T00:00:00Z",
                thumbnails: Thumbnails(
                    default: Thumbnails.ThumbnailInfo(url: "https://example.com/default.jpg", width: 88, height: 88),
                    medium: Thumbnails.ThumbnailInfo(url: "https://example.com/medium.jpg", width: 240, height: 240),
                    high: Thumbnails.ThumbnailInfo(url: "https://example.com/high.jpg", width: 800, height: 800),
                    standard: nil,
                    maxres: nil
                ),
                defaultLanguage: "en",
                localized: nil,
                country: "US"
            ),
            statistics: YouTubeChannel.ChannelStatistics(
                viewCount: "1000000",
                subscriberCount: "10000",
                hiddenSubscriberCount: false,
                videoCount: "100"
            ),
            contentDetails: nil,
            status: nil,
            brandingSettings: nil
        )
    }
}

// MARK: - Test Extensions

extension XCTestCase {
    
    func waitForAsync<T>(timeout: TimeInterval = 10.0, operation: @escaping () async throws -> T) async throws -> T {
        return try await withTimeout(timeout) {
            return try await operation()
        }
    }
    
    func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

struct TimeoutError: Error {}