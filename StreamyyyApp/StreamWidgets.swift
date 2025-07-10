//
//  StreamWidgets.swift
//  StreamyyyApp
//
//  Created by Claude on 2025-07-09.
//  Copyright © 2025 Streamyyy. All rights reserved.
//

import WidgetKit
import SwiftUI
import Intents
import Foundation

// MARK: - Widget Configuration

struct StreamWidgetProvider: IntentTimelineProvider {
    
    typealias Entry = StreamWidgetEntry
    typealias Intent = StreamWidgetConfigurationIntent
    
    // MARK: - Timeline Provider Methods
    
    func placeholder(in context: Context) -> StreamWidgetEntry {
        StreamWidgetEntry(
            date: Date(),
            configuration: StreamWidgetConfigurationIntent(),
            streamData: StreamData.placeholder,
            relevance: nil
        )
    }
    
    func getSnapshot(for configuration: StreamWidgetConfigurationIntent, in context: Context, completion: @escaping (StreamWidgetEntry) -> Void) {
        let entry = StreamWidgetEntry(
            date: Date(),
            configuration: configuration,
            streamData: StreamData.snapshot,
            relevance: nil
        )
        completion(entry)
    }
    
    func getTimeline(for configuration: StreamWidgetConfigurationIntent, in context: Context, completion: @escaping (Timeline<StreamWidgetEntry>) -> Void) {
        
        // Fetch live stream data
        fetchLiveStreams(for: configuration) { streamData in
            let currentDate = Date()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 2, to: currentDate) ?? currentDate
            
            let entry = StreamWidgetEntry(
                date: currentDate,
                configuration: configuration,
                streamData: streamData,
                relevance: TimelineEntryRelevance(score: streamData.relevanceScore)
            )
            
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchLiveStreams(for configuration: StreamWidgetConfigurationIntent, completion: @escaping (StreamData) -> Void) {
        // Create background task to fetch data
        let task = URLSession.shared.dataTask(with: createStreamRequest(for: configuration)) { data, response, error in
            
            // Handle network error
            if let error = error {
                print("Widget network error: \(error)")
                completion(StreamData.error)
                return
            }
            
            // Parse response
            guard let data = data else {
                completion(StreamData.error)
                return
            }
            
            do {
                let streamData = try JSONDecoder().decode(StreamData.self, from: data)
                completion(streamData)
            } catch {
                print("Widget JSON decode error: \(error)")
                completion(StreamData.error)
            }
        }
        
        task.resume()
    }
    
    private func createStreamRequest(for configuration: StreamWidgetConfigurationIntent) -> URLRequest {
        // Create API request based on configuration
        var urlComponents = URLComponents(string: "https://api.streamyyy.com/v1/live-streams")!
        
        var queryItems: [URLQueryItem] = []
        
        // Add filters based on configuration
        if let category = configuration.category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        if let platform = configuration.platform {
            queryItems.append(URLQueryItem(name: "platform", value: platform))
        }
        
        queryItems.append(URLQueryItem(name: "limit", value: "3"))
        queryItems.append(URLQueryItem(name: "sort", value: "viewers"))
        
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication headers if needed
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "StreamyyyAPIKey") as? String {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
}

// MARK: - Widget Entry

struct StreamWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: StreamWidgetConfigurationIntent
    let streamData: StreamData
    let relevance: TimelineEntryRelevance?
}

// MARK: - Stream Data Models

struct StreamData: Codable {
    let streams: [LiveStream]
    let totalViewers: Int
    let lastUpdated: Date
    let status: String
    
    var relevanceScore: Float {
        // Calculate relevance based on viewer count and recency
        let viewerScore = min(Float(totalViewers) / 10000.0, 1.0)
        let timeScore = max(0.0, 1.0 - Float(Date().timeIntervalSince(lastUpdated)) / 3600.0)
        return (viewerScore + timeScore) / 2.0
    }
    
    static let placeholder = StreamData(
        streams: [
            LiveStream(
                id: "1",
                title: "Amazing Gaming Stream",
                streamer: "CoolStreamer",
                platform: "Twitch",
                viewers: 1250,
                category: "Gaming",
                thumbnailURL: nil,
                isLive: true
            ),
            LiveStream(
                id: "2",
                title: "Music Performance Live",
                streamer: "MusicArtist",
                platform: "YouTube",
                viewers: 890,
                category: "Music",
                thumbnailURL: nil,
                isLive: true
            )
        ],
        totalViewers: 2140,
        lastUpdated: Date(),
        status: "active"
    )
    
    static let snapshot = StreamData(
        streams: [
            LiveStream(
                id: "snap1",
                title: "Widget Preview Stream",
                streamer: "PreviewStreamer",
                platform: "Twitch",
                viewers: 2500,
                category: "Just Chatting",
                thumbnailURL: nil,
                isLive: true
            )
        ],
        totalViewers: 2500,
        lastUpdated: Date(),
        status: "active"
    )
    
    static let error = StreamData(
        streams: [],
        totalViewers: 0,
        lastUpdated: Date(),
        status: "error"
    )
}

struct LiveStream: Codable, Identifiable {
    let id: String
    let title: String
    let streamer: String
    let platform: String
    let viewers: Int
    let category: String
    let thumbnailURL: String?
    let isLive: Bool
}

// MARK: - Widget Views

struct StreamWidgetView: View {
    let entry: StreamWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallStreamWidget(entry: entry)
        case .systemMedium:
            MediumStreamWidget(entry: entry)
        case .systemLarge:
            LargeStreamWidget(entry: entry)
        @unknown default:
            SmallStreamWidget(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallStreamWidget: View {
    let entry: StreamWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                
                Text("LIVE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
                
                Spacer()
                
                Text("\(entry.streamData.totalViewers.formatted())")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Stream info
            if let topStream = entry.streamData.streams.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(topStream.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                    
                    Text(topStream.streamer)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(topStream.platform)
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text("\(topStream.viewers.formatted())")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No live streams")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .widgetURL(URL(string: "streamyyy://widget/open"))
    }
}

// MARK: - Medium Widget

struct MediumStreamWidget: View {
    let entry: StreamWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
                
                Text("Live Streams")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(entry.streamData.totalViewers.formatted())")
                        .font(.system(size: 12, weight: .medium))
                    
                    Text("viewers")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            // Stream list
            if entry.streamData.streams.isEmpty {
                Spacer()
                Text("No live streams available")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ForEach(entry.streamData.streams.prefix(2)) { stream in
                    StreamRowView(stream: stream)
                    
                    if stream.id != entry.streamData.streams.prefix(2).last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .widgetURL(URL(string: "streamyyy://widget/open"))
    }
}

// MARK: - Large Widget

struct LargeStreamWidget: View {
    let entry: StreamWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 18))
                
                Text("Live Streams")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(entry.streamData.totalViewers.formatted())")
                        .font(.system(size: 14, weight: .medium))
                    
                    Text("total viewers")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            // Stream list
            if entry.streamData.streams.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    
                    Text("No live streams available")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("Check your connection")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ForEach(entry.streamData.streams.prefix(3)) { stream in
                    StreamRowView(stream: stream, isLarge: true)
                    
                    if stream.id != entry.streamData.streams.prefix(3).last?.id {
                        Divider()
                    }
                }
            }
            
            // Last updated
            HStack {
                Spacer()
                Text("Updated \(entry.date.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .widgetURL(URL(string: "streamyyy://widget/open"))
    }
}

// MARK: - Stream Row View

struct StreamRowView: View {
    let stream: LiveStream
    let isLarge: Bool
    
    init(stream: LiveStream, isLarge: Bool = false) {
        self.stream = stream
        self.isLarge = isLarge
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Live indicator
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            // Stream info
            VStack(alignment: .leading, spacing: 2) {
                Text(stream.title)
                    .font(.system(size: isLarge ? 12 : 11, weight: .medium))
                    .lineLimit(1)
                
                HStack {
                    Text(stream.streamer)
                        .font(.system(size: isLarge ? 11 : 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(stream.platform)
                        .font(.system(size: isLarge ? 10 : 9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(platformColor(stream.platform).opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Viewer count
            VStack(alignment: .trailing) {
                Text("\(stream.viewers.formatted())")
                    .font(.system(size: isLarge ? 11 : 10, weight: .medium))
                
                if isLarge {
                    Text("viewers")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .widgetURL(URL(string: "streamyyy://stream/\(stream.id)"))
    }
    
    private func platformColor(_ platform: String) -> Color {
        switch platform.lowercased() {
        case "twitch":
            return .purple
        case "youtube":
            return .red
        case "kick":
            return .green
        default:
            return .blue
        }
    }
}

// MARK: - Widget Configuration

struct StreamWidget: Widget {
    let kind: String = "StreamWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: StreamWidgetConfigurationIntent.self,
            provider: StreamWidgetProvider()
        ) { entry in
            StreamWidgetView(entry: entry)
        }
        .configurationDisplayName("Live Streams")
        .description("Stay updated with your favorite live streams")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Bundle

@main
struct StreamWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreamWidget()
        if #available(iOS 16.0, *) {
            StreamLockScreenWidget()
        }
    }
}

// MARK: - iOS 16+ Lock Screen Widget

@available(iOS 16.0, *)
struct StreamLockScreenWidget: Widget {
    let kind: String = "StreamLockScreenWidget"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: StreamWidgetConfigurationIntent.self,
            provider: StreamWidgetProvider()
        ) { entry in
            StreamLockScreenView(entry: entry)
        }
        .configurationDisplayName("Live Streams")
        .description("Quick access to live streams")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@available(iOS 16.0, *)
struct StreamLockScreenView: View {
    let entry: StreamWidgetEntry
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            CircularLockScreenWidget(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenWidget(entry: entry)
        case .accessoryInline:
            InlineLockScreenWidget(entry: entry)
        default:
            Text("Unsupported")
        }
    }
}

@available(iOS 16.0, *)
struct CircularLockScreenWidget: View {
    let entry: StreamWidgetEntry
    
    var body: some View {
        VStack {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
            
            Text("\(entry.streamData.totalViewers.formatted(.number.notation(.compactName)))")
                .font(.system(size: 10, weight: .medium))
        }
        .widgetURL(URL(string: "streamyyy://widget/open"))
    }
}

@available(iOS 16.0, *)
struct RectangularLockScreenWidget: View {
    let entry: StreamWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                
                Text("Live Streams")
                    .font(.system(size: 12, weight: .medium))
                
                Spacer()
            }
            
            if let topStream = entry.streamData.streams.first {
                HStack {
                    Text(topStream.title)
                        .font(.system(size: 10))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(topStream.viewers.formatted(.number.notation(.compactName)))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No live streams")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .widgetURL(URL(string: "streamyyy://widget/open"))
    }
}

@available(iOS 16.0, *)
struct InlineLockScreenWidget: View {
    let entry: StreamWidgetEntry
    
    var body: some View {
        HStack {
            Image(systemName: "play.circle.fill")
                .foregroundColor(.red)
            
            if let topStream = entry.streamData.streams.first {
                Text("\(topStream.title) - \(topStream.viewers.formatted(.number.notation(.compactName))) viewers")
                    .lineLimit(1)
            } else {
                Text("No live streams")
            }
        }
        .widgetURL(URL(string: "streamyyy://widget/open"))
    }
}

// MARK: - Widget Preview

struct StreamWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StreamWidgetView(entry: StreamWidgetEntry(
                date: Date(),
                configuration: StreamWidgetConfigurationIntent(),
                streamData: StreamData.placeholder,
                relevance: nil
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            StreamWidgetView(entry: StreamWidgetEntry(
                date: Date(),
                configuration: StreamWidgetConfigurationIntent(),
                streamData: StreamData.placeholder,
                relevance: nil
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            StreamWidgetView(entry: StreamWidgetEntry(
                date: Date(),
                configuration: StreamWidgetConfigurationIntent(),
                streamData: StreamData.placeholder,
                relevance: nil
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}

// MARK: - Widget Configuration Intent

class StreamWidgetConfigurationIntent: INIntent {
    @NSManaged public var category: String?
    @NSManaged public var platform: String?
    @NSManaged public var maxStreams: NSNumber?
}