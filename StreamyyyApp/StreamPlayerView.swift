//
//  StreamPlayerView.swift
//  StreamyyyApp
//
//  Unified stream player view - imports the new StreamEngine implementation
//  Created by Claude Code on 2025-07-09
//

import SwiftUI
import WebKit

// MARK: - Main StreamPlayerView
/// Main StreamPlayerView that uses the new unified StreamEngine
struct StreamPlayerView: View {
    let stream: Stream
    @Binding var isPresented: Bool
    
    var body: some View {
        UnifiedStreamPlayerView(
            stream: stream,
            isPresented: $isPresented
        )
    }
}

// MARK: - Legacy Support
/// Legacy StreamPlayerView for backward compatibility with SimpleStream
struct LegacyStreamPlayerView: View {
    let stream: SimpleStream
    @Binding var isPresented: Bool
    
    var body: some View {
        let fullStream = Stream(
            url: stream.url,
            platform: Platform.detect(from: stream.url),
            title: stream.title
        )
        
        // Update stream properties from SimpleStream
        fullStream.isLive = stream.isLive
        fullStream.viewerCount = stream.viewerCount
        fullStream.category = stream.gameTitle
        
        return UnifiedStreamPlayerView(
            stream: fullStream,
            isPresented: $isPresented
        )
    }
}

// MARK: - SimpleStream Model (Legacy)
/// Legacy SimpleStream model for backward compatibility
struct SimpleStream {
    let title: String
    let url: String
    let platform: String
    let isLive: Bool
    let viewerCount: Int
    let gameTitle: String?
    
    var formattedViewerCount: String {
        if viewerCount >= 1000000 {
            return String(format: "%.1fM", Double(viewerCount) / 1000000.0)
        } else if viewerCount >= 1000 {
            return String(format: "%.1fK", Double(viewerCount) / 1000.0)
        } else {
            return "\(viewerCount)"
        }
    }
}

// MARK: - Preview
#Preview {
    StreamPlayerView(
        stream: Stream(
            url: "https://www.twitch.tv/shroud",
            platform: .twitch,
            title: "Test Stream"
        ),
        isPresented: .constant(true)
    )
}