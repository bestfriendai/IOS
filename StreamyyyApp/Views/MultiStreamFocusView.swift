//
//  MultiStreamFocusView.swift
//  StreamyyyApp
//
//  Focused view for a single stream from multistream
//

import SwiftUI

struct MultiStreamFocusView: View {
    let streamId: String
    @EnvironmentObject var navigationCoordinator: NavigationCoordinator
    @EnvironmentObject var streamManager: StreamManager
    @State private var stream: StreamModel?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let stream = stream {
                VStack {
                    // Stream player area
                    VStack {
                        // Placeholder for actual stream player
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.gray.opacity(0.3))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay(
                                VStack(spacing: 16) {
                                    Image(systemName: "play.tv.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white)
                                    
                                    Text("Focused Stream Player")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(stream.title)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            )
                    }
                    .padding()
                    
                    // Stream info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(stream.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        HStack {
                            Text(stream.channelName ?? "Unknown")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.purple)
                            
                            Spacer()
                            
                            if stream.isLive {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 6, height: 6)
                                    
                                    Text("LIVE")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        if let gameName = stream.gameName {
                            Text("Playing: \(gameName)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    Spacer()
                }
            } else {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading stream...")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Button(action: {
                        navigationCoordinator.pop()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadStream()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        navigationCoordinator.pop()
                    }
                }
        )
    }
    
    private func loadStream() {
        stream = streamManager.streams.first { $0.id == streamId }
    }
}

#Preview {
    MultiStreamFocusView(streamId: "test")
        .environmentObject(NavigationCoordinator())
        .environmentObject(StreamManager())
}