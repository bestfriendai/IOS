//
//  TabViewModel.swift
//  StreamyyyApp
//
//  Simple tab view model for managing tab state
//

import SwiftUI
import Combine

@MainActor
class TabViewModel: ObservableObject {
    @Published var selectedTab = 0
    @Published var showingNotifications = false
    @Published var notificationCount = 0
    @Published var isLoading = false
    
    init() {
        // Initialize any necessary state
    }
    
    func selectTab(_ tab: Int) {
        selectedTab = tab
    }
    
    func updateNotificationCount(_ count: Int) {
        notificationCount = count
        showingNotifications = count > 0
    }
    
    func clearNotifications() {
        notificationCount = 0
        showingNotifications = false
    }
}