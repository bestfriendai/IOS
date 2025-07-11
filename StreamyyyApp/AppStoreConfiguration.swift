//
//  AppStoreConfiguration.swift
//  StreamyyyApp
//
//  App Store Connect configuration and production readiness
//

import Foundation
import UIKit
import StoreKit

// MARK: - App Store Configuration
public struct AppStoreConfiguration {
    
    // MARK: - App Information
    public static let appName = "Streamyyy"
    public static let appSubtitle = "Multi-Stream Viewer"
    public static let appDescription = """
    Watch multiple live streams simultaneously with Streamyyy. 
    Perfect for streamers, esports fans, and content creators who want to follow multiple channels at once.
    
    Features:
    • Watch up to 20+ streams simultaneously
    • Support for Twitch, YouTube, and more platforms
    • Custom layouts and grid arrangements
    • Picture-in-picture mode
    • Real-time chat integration
    • Stream notifications and alerts
    • Premium subscription with advanced features
    """
    
    public static let keywords = [
        "streaming", "twitch", "youtube", "multi-stream", "viewer", 
        "esports", "gaming", "live", "chat", "entertainment"
    ]
    
    // MARK: - App Store Categories
    public static let primaryCategory = "Entertainment"
    public static let secondaryCategory = "Social Networking"
    
    // MARK: - Content Rating
    public static let contentRating = "12+" // Due to live streaming content
    
    // MARK: - Screenshots Requirements
    public static let screenshotRequirements = """
    Required Screenshots (2048x2732 for iPad, 1290x2796 for iPhone):
    1. Multi-stream grid view showing 4+ streams
    2. Single stream fullscreen view with chat
    3. Stream discovery/browse screen
    4. Subscription/premium features screen
    5. Settings and customization screen
    """
    
    // MARK: - App Preview Requirements
    public static let appPreviewRequirements = """
    App Preview Video (up to 30 seconds):
    • Show multi-stream functionality
    • Demonstrate stream switching
    • Highlight key features
    • Show responsive design across devices
    """
    
    // MARK: - Privacy Information
    public static let privacyPractices = [
        "Data Used to Track You": [
            "Usage Data": "To improve app performance and user experience",
            "Identifiers": "For analytics and crash reporting"
        ],
        "Data Linked to You": [
            "User Content": "Favorite streams and preferences",
            "Usage Data": "App interaction analytics",
            "Identifiers": "Account management"
        ],
        "Data Not Linked to You": [
            "Diagnostics": "Crash reports and error logs"
        ]
    ]
    
    // MARK: - Subscription Information
    public static let subscriptionInfo = """
    Streamyyy Pro Subscription:
    • Monthly: $9.99/month
    • Yearly: $99.99/year (Save 17%)
    
    Free Features:
    • Up to 4 simultaneous streams
    • Basic layouts
    • Standard support
    
    Pro Features:
    • Up to 20+ simultaneous streams
    • Advanced custom layouts
    • Priority customer support
    • Ad-free experience
    • Real-time analytics
    
    Payment will be charged to iTunes Account at confirmation of purchase.
    Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.
    Account will be charged for renewal within 24-hours prior to the end of the current period.
    Subscriptions may be managed by the user and auto-renewal may be turned off by going to the user's Account Settings after purchase.
    """
    
    // MARK: - Review Guidelines Compliance
    public static func validateAppStoreCompliance() -> [String] {
        var issues: [String] = []
        
        // Check for required configurations
        if Config.Stripe.publishableKey.contains("YOUR_") {
            issues.append("Stripe publishable key not configured")
        }
        
        if Config.Sentry.dsn.contains("YOUR_") {
            issues.append("Sentry DSN not configured")
        }
        
        // Check for test mode configurations
        #if DEBUG
        // This is expected in debug mode
        #else
        if Config.isProduction == false {
            issues.append("Production flag not set correctly")
        }
        #endif
        
        // Validate required Info.plist entries
        let bundle = Bundle.main
        
        if bundle.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") == nil {
            issues.append("Missing App Tracking Transparency usage description")
        }
        
        if bundle.object(forInfoDictionaryKey: "NSCameraUsageDescription") == nil {
            issues.append("Missing camera usage description (if using camera)")
        }
        
        if bundle.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") == nil {
            issues.append("Missing microphone usage description (if using microphone)")
        }
        
        return issues
    }
}

// MARK: - App Store Connect Manager
@MainActor
public class AppStoreConnectManager: ObservableObject {
    public static let shared = AppStoreConnectManager()
    
    @Published public var isAppStoreAvailable = false
    @Published public var canMakePayments = false
    @Published public var appStoreProducts: [SKProduct] = []
    
    private init() {
        checkAppStoreAvailability()
    }
    
    // MARK: - App Store Availability
    private func checkAppStoreAvailability() {
        isAppStoreAvailable = SKPaymentQueue.canMakePayments()
        canMakePayments = SKPaymentQueue.canMakePayments()
    }
    
    // MARK: - Product Management
    public func loadProducts() async {
        let productIdentifiers = Set([
            Config.Stripe.premiumMonthlyPlanId,
            Config.Stripe.premiumYearlyPlanId,
            Config.Stripe.proMonthlyPlanId,
            Config.Stripe.proYearlyPlanId
        ])
        
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        
        // In a real implementation, you'd use SKProductsRequestDelegate
        // For now, this is a placeholder
        print("📱 Loading App Store products: \(productIdentifiers)")
    }
    
    // MARK: - App Store Review
    public func requestAppStoreReview() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        SKStoreReviewController.requestReview(in: windowScene)
        
        // Track analytics
        AnalyticsManager.shared.track(name: "app_store_review_requested")
    }
    
    // MARK: - App Store Navigation
    public func openAppStore() {
        guard let url = URL(string: Config.URLs.appStore) else { return }
        UIApplication.shared.open(url)
        
        // Track analytics
        AnalyticsManager.shared.track(name: "app_store_opened")
    }
    
    // MARK: - Share App
    public func shareApp() -> [Any] {
        let shareText = "Check out Streamyyy - the best multi-stream viewer for iOS!"
        let shareURL = URL(string: Config.URLs.appStore)!
        
        // Track analytics
        AnalyticsManager.shared.track(name: "app_shared")
        
        return [shareText, shareURL]
    }
}

// MARK: - Production Checklist
public struct ProductionChecklist {
    
    public static let checklist = [
        ChecklistItem(
            title: "App Store Configuration",
            items: [
                "App name, subtitle, and description finalized",
                "Keywords optimized for search",
                "Screenshots captured for all device sizes",
                "App preview video created and optimized",
                "App icon created for all required sizes",
                "Privacy policy and terms of service links working"
            ]
        ),
        ChecklistItem(
            title: "Technical Configuration",
            items: [
                "Production API endpoints configured",
                "Stripe live keys configured",
                "Push notifications properly set up",
                "Analytics tracking implemented",
                "Error reporting configured (Sentry)",
                "All TODO comments addressed",
                "Debug logging disabled in production"
            ]
        ),
        ChecklistItem(
            title: "Legal and Compliance",
            items: [
                "Privacy policy updated and accessible",
                "Terms of service updated and accessible",
                "App Tracking Transparency implemented",
                "GDPR compliance measures in place",
                "Content rating accurately reflects app content",
                "Subscription terms clearly displayed"
            ]
        ),
        ChecklistItem(
            title: "Quality Assurance",
            items: [
                "All user flows tested thoroughly",
                "Subscription purchase and management tested",
                "Push notifications working correctly",
                "Offline functionality tested",
                "Performance tested on older devices",
                "Accessibility features tested with VoiceOver",
                "Memory leaks and crashes resolved"
            ]
        ),
        ChecklistItem(
            title: "Localization",
            items: [
                "English localization complete",
                "Additional languages localized (if applicable)",
                "Date, time, and currency formatting correct",
                "Text fits properly in all layouts",
                "Cultural considerations addressed"
            ]
        ),
        ChecklistItem(
            title: "Monetization",
            items: [
                "Subscription tiers clearly defined",
                "Payment flow thoroughly tested",
                "Receipt validation implemented",
                "Refund policy clearly stated",
                "Free trial terms explained",
                "Upgrade/downgrade flows working"
            ]
        )
    ]
    
    public static func getCompletionPercentage() -> Double {
        let totalItems = checklist.flatMap { $0.items }.count
        // In a real implementation, you'd track completion status
        // For now, return a placeholder
        return 0.85 // 85% complete
    }
}

public struct ChecklistItem {
    let title: String
    let items: [String]
    
    public init(title: String, items: [String]) {
        self.title = title
        self.items = items
    }
}

// MARK: - App Store Analytics
extension AnalyticsManager {
    public func trackAppStoreEvent(_ event: String, metadata: [String: Any] = [:]) {
        var properties = metadata
        properties["source"] = "app_store"
        track(name: event, properties: properties)
    }
    
    public func trackSubscriptionPurchaseIntent(plan: String) {
        trackAppStoreEvent("subscription_purchase_intent", metadata: [
            "plan": plan
        ])
    }
    
    public func trackAppStoreReviewRequest() {
        trackAppStoreEvent("review_request_shown")
    }
    
    public func trackAppShared(method: String) {
        trackAppStoreEvent("app_shared", metadata: [
            "method": method
        ])
    }
}