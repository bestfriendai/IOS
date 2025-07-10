//
//  PopupNotificationView.swift
//  StreamyyyApp
//
//  SwiftUI view for displaying popup notifications with animations and gestures
//  Created by Claude Code on 2025-07-10
//

import SwiftUI

// MARK: - Popup Notification View
public struct PopupNotificationView: View {
    @ObservedObject private var notificationManager = PopupNotificationManager.shared
    @State private var appearing = false
    @State private var textWidth: CGFloat = 0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if notificationManager.isVisible,
               let notification = notificationManager.currentNotification {
                
                notificationCard(for: notification)
                    .opacity(appearing ? 1 : 0)
                    .scaleEffect(appearing ? 1 : 0.8)
                    .offset(y: yOffset)
                    .offset(notificationManager.dragOffset)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appearing)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: notificationManager.dragOffset)
                    .onAppear {
                        withAnimation {
                            appearing = true
                        }
                    }
                    .onDisappear {
                        appearing = false
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                notificationManager.handleDragChange(value)
                            }
                            .onEnded { _ in
                                notificationManager.handleDragEnd()
                            }
                    )
                    .onTapGesture {
                        handleNotificationTap(notification)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: notificationManager.position == .top ? .top : .bottom)
        .padding(.horizontal, 16)
        .padding(notificationManager.position == .top ? .top : .bottom, safeAreaInset)
        .allowsHitTesting(notificationManager.isVisible)
    }
    
    // MARK: - Notification Card
    
    private func notificationCard(for notification: PopupNotification) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: notification.icon)
                .font(.title2)
                .foregroundColor(notification.color)
                .frame(width: 24, height: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(notification.displayMessage)
                    .font(.system(.caption, design: .default))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Actions
            notificationActions(for: notification)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            // Drag indicator
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.color.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(notificationManager.isDragging ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: notificationManager.isDragging)
    }
    
    // MARK: - Notification Actions
    
    @ViewBuilder
    private func notificationActions(for notification: PopupNotification) -> some View {
        HStack(spacing: 8) {
            if notification.type == .streamError {
                // Retry button for errors
                Button(action: {
                    handleRetryAction(notification)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(notification.color)
                        .clipShape(Circle())
                }
            }
            
            // Dismiss button
            Button(action: {
                notificationManager.dismiss(reason: .userAction)
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary)
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var yOffset: CGFloat {
        switch notificationManager.animationState {
        case .hidden:
            return notificationManager.position == .top ? -200 : 200
        case .showing:
            return 0
        case .dismissing:
            return notificationManager.position == .top ? -200 : 200
        }
    }
    
    private var safeAreaInset: CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return notificationManager.position == .top ? 
                window.safeAreaInsets.top + 8 : 
                window.safeAreaInsets.bottom + 8
        }
        return notificationManager.position == .top ? 44 : 34
    }
    
    // MARK: - Actions
    
    private func handleNotificationTap(_ notification: PopupNotification) {
        // Handle different notification types
        switch notification.type {
        case .streamSuccess, .streamError:
            if let streamId = notification.data["streamId"] {
                // Navigate to stream or show stream details
                handleStreamNotificationTap(streamId: streamId)
            }
        case .layoutChange:
            if let layoutRaw = notification.data["layout"],
               let layout = MultiStreamLayout(rawValue: layoutRaw) {
                // Show layout options or animate to new layout
                handleLayoutNotificationTap(layout: layout)
            }
        case .networkStatus:
            // Show network settings or status
            handleNetworkNotificationTap()
        case .custom:
            // Handle custom notification data
            handleCustomNotificationTap(notification)
        }
        
        // Dismiss after handling
        notificationManager.dismiss(reason: .userAction)
    }
    
    private func handleRetryAction(_ notification: PopupNotification) {
        if let streamId = notification.data["streamId"] {
            Task {
                // Retry the failed stream operation
                await retryStreamOperation(streamId: streamId)
            }
        }
        notificationManager.dismiss(reason: .userAction)
    }
    
    private func handleStreamNotificationTap(streamId: String) {
        // Focus on the stream or show stream details
        Task {
            if let manager = MultiStreamManager.shared as? MultiStreamManager,
               let slotIndex = manager.activeStreams.firstIndex(where: { $0.stream?.id == streamId }) {
                await manager.focusOnStream(at: slotIndex)
            }
        }
    }
    
    private func handleLayoutNotificationTap(layout: MultiStreamLayout) {
        // Could trigger layout tutorial or options
        print("Layout notification tapped: \(layout.displayName)")
    }
    
    private func handleNetworkNotificationTap() {
        // Could open network settings or status view
        print("Network notification tapped")
    }
    
    private func handleCustomNotificationTap(_ notification: PopupNotification) {
        // Handle custom notification actions based on data
        print("Custom notification tapped: \(notification.data)")
    }
    
    private func retryStreamOperation(streamId: String) async {
        // Retry the failed stream operation
        await MultiStreamManager.shared.retryFailedOperations()
    }
}

// MARK: - Preview Support
#if DEBUG
struct PopupNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Notification overlay
            PopupNotificationView()
                .onAppear {
                    // Show preview notification
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        PopupNotificationManager.shared.showStreamSuccess(
                            title: "Stream Added",
                            message: "Successfully added stream to multi-view",
                            streamId: "test-stream"
                        )
                    }
                }
        }
    }
}
#endif

// MARK: - Notification Container View
/// A container view that can be added to your main app view to display popup notifications
public struct PopupNotificationContainer<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        ZStack {
            content
            PopupNotificationView()
        }
    }
}

// MARK: - ViewModifier for easy integration
public struct PopupNotificationModifier: ViewModifier {
    public func body(content: Content) -> some View {
        ZStack {
            content
            PopupNotificationView()
        }
    }
}

public extension View {
    func popupNotifications() -> some View {
        modifier(PopupNotificationModifier())
    }
}

// MARK: - Haptic Feedback Extensions
public extension PopupNotificationManager {
    func triggerHapticFeedback(for type: PopupNotificationType) {
        guard enableHaptics else { return }
        
        let feedback: UINotificationFeedbackGenerator.FeedbackType
        switch type {
        case .streamSuccess:
            feedback = .success
        case .streamError:
            feedback = .error
        case .layoutChange, .networkStatus, .custom:
            feedback = .warning
        }
        
        UINotificationFeedbackGenerator().notificationOccurred(feedback)
    }
}