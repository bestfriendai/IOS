//
//  PopupNotificationManager.swift
//  StreamyyyApp
//
//  Multi-stream popup notification state management with real-time updates
//  Created by Claude Code on 2025-07-10
//

import SwiftUI
import Combine
import UserNotifications

// MARK: - Popup Notification Manager
@MainActor
public class PopupNotificationManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = PopupNotificationManager()
    
    // MARK: - Published Properties
    @Published public var isVisible = false
    @Published public var currentNotification: PopupNotification?
    @Published public var notificationQueue: [PopupNotification] = []
    @Published public var dismissTimer: Timer?
    @Published public var animationState: AnimationState = .hidden
    @Published public var position: PopupPosition = .top
    @Published public var isDragging = false
    @Published public var dragOffset: CGSize = .zero
    
    // MARK: - Configuration
    @Published public var isEnabled = true
    @Published public var autoDismissDelay: Double = 4.0
    @Published public var maxQueueSize = 5
    @Published public var showInBackground = false
    @Published public var enableHaptics = true
    @Published public var enableSounds = true
    @Published public var groupSimilarNotifications = true
    
    // MARK: - State Management
    @Published public var totalNotificationCount = 0
    @Published public var unreadCount = 0
    @Published public var lastShownTime: Date?
    @Published public var isProcessingQueue = false
    @Published public var dismissalReason: DismissalReason?
    
    private var cancellables = Set<AnyCancellable>()
    private let hapticFeedback = UINotificationFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    private init() {
        setupObservers()
        setupNotificationCenter()
    }
    
    // MARK: - Setup Methods
    
    private func setupObservers() {
        // Auto-dismiss timer
        $currentNotification
            .sink { [weak self] notification in
                self?.handleNotificationChange(notification)
            }
            .store(in: &cancellables)
        
        // Animation state observer
        $animationState
            .sink { [weak self] state in
                self?.handleAnimationStateChange(state)
            }
            .store(in: &cancellables)
        
        // App state observers
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
    }
    
    private func setupNotificationCenter() {
        // Listen for multi-stream events
        NotificationCenter.default.publisher(for: .streamAdded)
            .sink { [weak self] notification in
                if let streamId = notification.object as? String {
                    self?.showStreamAddedNotification(streamId: streamId)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .streamRemoved)
            .sink { [weak self] notification in
                if let streamId = notification.object as? String {
                    self?.showStreamRemovedNotification(streamId: streamId)
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .layoutChanged)
            .sink { [weak self] notification in
                if let layout = notification.object as? MultiStreamLayout {
                    self?.showLayoutChangedNotification(layout: layout)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    public func show(_ notification: PopupNotification) {
        guard isEnabled else { return }
        
        // Group similar notifications if enabled
        if groupSimilarNotifications,
           let existingIndex = notificationQueue.firstIndex(where: { $0.type == notification.type }) {
            notificationQueue[existingIndex] = notification.merged(with: notificationQueue[existingIndex])
        } else {
            // Add to queue
            notificationQueue.append(notification)
            
            // Limit queue size
            if notificationQueue.count > maxQueueSize {
                notificationQueue.removeFirst()
            }
        }
        
        totalNotificationCount += 1
        unreadCount += 1
        
        // Process queue if not currently showing
        if !isVisible {
            processQueue()
        }
    }
    
    public func showStreamSuccess(title: String, message: String, streamId: String? = nil) {
        let notification = PopupNotification(
            id: UUID().uuidString,
            type: .streamSuccess,
            title: title,
            message: message,
            icon: "checkmark.circle.fill",
            color: .green,
            data: streamId.map { ["streamId": $0] } ?? [:]
        )
        show(notification)
    }
    
    public func showStreamError(title: String, message: String, streamId: String? = nil) {
        let notification = PopupNotification(
            id: UUID().uuidString,
            type: .streamError,
            title: title,
            message: message,
            icon: "exclamationmark.triangle.fill",
            color: .red,
            data: streamId.map { ["streamId": $0] } ?? [:],
            autoDismiss: false // Keep errors visible
        )
        show(notification)
    }
    
    public func showLayoutChange(title: String, message: String, layout: MultiStreamLayout) {
        let notification = PopupNotification(
            id: UUID().uuidString,
            type: .layoutChange,
            title: title,
            message: message,
            icon: layout.icon,
            color: .blue,
            data: ["layout": layout.rawValue]
        )
        show(notification)
    }
    
    public func showNetworkStatus(title: String, message: String, isConnected: Bool) {
        let notification = PopupNotification(
            id: UUID().uuidString,
            type: .networkStatus,
            title: title,
            message: message,
            icon: isConnected ? "wifi" : "wifi.slash",
            color: isConnected ? .green : .red
        )
        show(notification)
    }
    
    public func showCustom(
        title: String,
        message: String,
        icon: String = "info.circle.fill",
        color: Color = .blue,
        autoDismiss: Bool = true,
        data: [String: String] = [:]
    ) {
        let notification = PopupNotification(
            id: UUID().uuidString,
            type: .custom,
            title: title,
            message: message,
            icon: icon,
            color: color,
            autoDismiss: autoDismiss,
            data: data
        )
        show(notification)
    }
    
    public func dismiss(reason: DismissalReason = .userAction) {
        dismissalReason = reason
        
        guard isVisible else { return }
        
        cancelDismissTimer()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            animationState = .dismissing
            dragOffset = .zero
            isDragging = false
        }
        
        // Update last shown time
        lastShownTime = Date()
        
        // Provide haptic feedback
        if enableHaptics {
            impactFeedback.impactOccurred()
        }
        
        // Complete dismissal after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.completeDismissal()
        }
    }
    
    public func dismissAll() {
        notificationQueue.removeAll()
        dismiss(reason: .userAction)
    }
    
    public func markAsRead() {
        if unreadCount > 0 {
            unreadCount -= 1
        }
        currentNotification?.markAsRead()
    }
    
    public func setPosition(_ position: PopupPosition) {
        self.position = position
    }
    
    public func setAutoDismissDelay(_ delay: Double) {
        autoDismissDelay = max(1.0, min(30.0, delay))
    }
    
    public func configure(
        enabled: Bool = true,
        autoDismissDelay: Double = 4.0,
        position: PopupPosition = .top,
        showInBackground: Bool = false,
        enableHaptics: Bool = true,
        enableSounds: Bool = true,
        groupSimilar: Bool = true
    ) {
        self.isEnabled = enabled
        self.autoDismissDelay = autoDismissDelay
        self.position = position
        self.showInBackground = showInBackground
        self.enableHaptics = enableHaptics
        self.enableSounds = enableSounds
        self.groupSimilarNotifications = groupSimilar
    }
    
    // MARK: - Private Methods
    
    private func processQueue() {
        guard !isProcessingQueue, !notificationQueue.isEmpty else { return }
        
        isProcessingQueue = true
        
        let nextNotification = notificationQueue.removeFirst()
        showNotification(nextNotification)
    }
    
    private func showNotification(_ notification: PopupNotification) {
        currentNotification = notification
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isVisible = true
            animationState = .showing
        }
        
        // Provide haptic feedback
        if enableHaptics {
            hapticFeedback.notificationOccurred(.success)
        }
        
        // Play sound if enabled
        if enableSounds {
            playNotificationSound(for: notification.type)
        }
        
        // Set up auto-dismiss timer if needed
        if notification.autoDismiss {
            setupDismissTimer()
        }
        
        isProcessingQueue = false
    }
    
    private func setupDismissTimer() {
        cancelDismissTimer()
        
        dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissDelay, repeats: false) { _ in
            Task { @MainActor in
                self.dismiss(reason: .timeout)
            }
        }
    }
    
    private func cancelDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = nil
    }
    
    private func completeDismissal() {
        isVisible = false
        animationState = .hidden
        currentNotification = nil
        dismissalReason = nil
        
        // Process next notification in queue if any
        if !notificationQueue.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.processQueue()
            }
        }
    }
    
    private func handleNotificationChange(_ notification: PopupNotification?) {
        if notification != nil {
            markAsRead()
        }
    }
    
    private func handleAnimationStateChange(_ state: AnimationState) {
        switch state {
        case .showing:
            break // Already handled in showNotification
        case .dismissing, .hidden:
            break // Already handled in dismiss/completeDismissal
        }
    }
    
    private func handleAppWillResignActive() {
        if !showInBackground {
            dismissAll()
        }
    }
    
    private func handleAppDidBecomeActive() {
        // Resume processing if there are queued notifications
        if !notificationQueue.isEmpty && !isVisible {
            processQueue()
        }
    }
    
    private func playNotificationSound(for type: PopupNotificationType) {
        // Implementation would play appropriate system sounds
        // For now, just use default notification sound
        if let soundID = type.systemSoundID {
            AudioServicesPlaySystemSound(soundID)
        }
    }
    
    // MARK: - Convenience Methods for Multi-Stream Events
    
    private func showStreamAddedNotification(streamId: String) {
        showStreamSuccess(
            title: "Stream Added",
            message: "Successfully added stream to multi-view",
            streamId: streamId
        )
    }
    
    private func showStreamRemovedNotification(streamId: String) {
        showCustom(
            title: "Stream Removed",
            message: "Stream removed from multi-view",
            icon: "minus.circle.fill",
            color: .orange,
            data: ["streamId": streamId]
        )
    }
    
    private func showLayoutChangedNotification(layout: MultiStreamLayout) {
        showLayoutChange(
            title: "Layout Changed",
            message: "Switched to \(layout.displayName)",
            layout: layout
        )
    }
    
    // MARK: - Drag Gesture Support
    
    public func handleDragStart() {
        isDragging = true
        cancelDismissTimer()
    }
    
    public func handleDragChange(_ value: DragGesture.Value) {
        dragOffset = value.translation
        
        // Dismiss if dragged far enough
        let dismissThreshold: CGFloat = position == .top ? -100 : 100
        let shouldDismiss = position == .top ? 
            dragOffset.y < dismissThreshold : 
            dragOffset.y > dismissThreshold
        
        if shouldDismiss {
            dismiss(reason: .swipe)
        }
    }
    
    public func handleDragEnd() {
        isDragging = false
        
        // Snap back if not dismissed
        if isVisible {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                dragOffset = .zero
            }
            
            // Restart auto-dismiss timer if needed
            if currentNotification?.autoDismiss == true {
                setupDismissTimer()
            }
        }
    }
}

// MARK: - Supporting Types

public struct PopupNotification: Identifiable, Codable {
    public let id: String
    public let type: PopupNotificationType
    public let title: String
    public let message: String
    public let icon: String
    public let color: Color
    public let autoDismiss: Bool
    public let data: [String: String]
    public let timestamp: Date
    public var isRead: Bool
    public var mergeCount: Int
    
    public init(
        id: String,
        type: PopupNotificationType,
        title: String,
        message: String,
        icon: String,
        color: Color,
        autoDismiss: Bool = true,
        data: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.icon = icon
        self.color = color
        self.autoDismiss = autoDismiss
        self.data = data
        self.timestamp = Date()
        self.isRead = false
        self.mergeCount = 1
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, message, icon, autoDismiss, data, timestamp, isRead, mergeCount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(PopupNotificationType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        icon = try container.decode(String.self, forKey: .icon)
        color = .blue // Default color for decoded notifications
        autoDismiss = try container.decode(Bool.self, forKey: .autoDismiss)
        data = try container.decode([String: String].self, forKey: .data)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        mergeCount = try container.decode(Int.self, forKey: .mergeCount)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(icon, forKey: .icon)
        try container.encode(autoDismiss, forKey: .autoDismiss)
        try container.encode(data, forKey: .data)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(mergeCount, forKey: .mergeCount)
    }
    
    public mutating func markAsRead() {
        isRead = true
    }
    
    public func merged(with other: PopupNotification) -> PopupNotification {
        var merged = self
        merged.mergeCount = max(mergeCount, other.mergeCount) + 1
        merged.timestamp = Date()
        return merged
    }
    
    public var displayMessage: String {
        if mergeCount > 1 {
            return "\(message) (\(mergeCount) similar)"
        }
        return message
    }
}

public enum PopupNotificationType: String, CaseIterable, Codable {
    case streamSuccess = "stream_success"
    case streamError = "stream_error"
    case layoutChange = "layout_change"
    case networkStatus = "network_status"
    case custom = "custom"
    
    public var systemSoundID: SystemSoundID? {
        switch self {
        case .streamSuccess:
            return 1016 // SMS received
        case .streamError:
            return 1053 // Error sound
        case .layoutChange:
            return 1519 // Begin recording
        case .networkStatus:
            return 1003 // SMS received 3
        case .custom:
            return 1016 // Default
        }
    }
}

public enum PopupPosition: String, CaseIterable {
    case top = "top"
    case bottom = "bottom"
    
    public var displayName: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        }
    }
}

public enum AnimationState: String, CaseIterable {
    case hidden = "hidden"
    case showing = "showing"
    case dismissing = "dismissing"
}

public enum DismissalReason: String, CaseIterable {
    case userAction = "user_action"
    case timeout = "timeout"
    case swipe = "swipe"
    case systemInterrupt = "system_interrupt"
}

// MARK: - Color Extension for Codable
extension Color: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let colorName = try container.decode(String.self)
        
        switch colorName {
        case "red": self = .red
        case "green": self = .green
        case "blue": self = .blue
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "purple": self = .purple
        case "pink": self = .pink
        case "gray": self = .gray
        default: self = .blue
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // This is a simplified encoding - in a real app you'd want more robust color encoding
        try container.encode("blue")
    }
}

// MARK: - AudioServices Import
import AudioToolbox