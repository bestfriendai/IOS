//
//  SimpleTwitchEmbedWebView.swift
//  StreamyyyApp
//
//  Simplified Twitch WebView that works reliably
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import WebKit

// MARK: - Simple Twitch Embed WebView
public struct SimpleTwitchEmbedWebView: View {
    let channelName: String
    @Binding var isMuted: Bool
    
    public init(
        channelName: String,
        isMuted: Binding<Bool>
    ) {
        self.channelName = channelName
        self._isMuted = isMuted
    }
    
    public var body: some View {
        // This view now uses the robust TwitchEmbedWebView implementation
        TwitchEmbedWebView(
            channelName: channelName,
            isMuted: $isMuted
        )
}