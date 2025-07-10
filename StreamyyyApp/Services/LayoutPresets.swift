//
//  LayoutPresets.swift
//  StreamyyyApp
//
//  Predefined layout templates and configurations for different grid patterns
//

import Foundation
import SwiftUI

public class LayoutPresets {
    
    // MARK: - Static Layout Presets
    
    /// Get all available layout presets
    public static func getAllPresets() -> [Layout] {
        return [
            createSingleStreamLayout(),
            createGrid2x2Layout(),
            createGrid3x3Layout(),
            createGrid4x4Layout(),
            createStackLayout(),
            createCarouselLayout(),
            createFocusLayout(),
            createSplitViewLayout(),
            createMosaicLayout(),
            createTheaterLayout(),
            createDashboardLayout(),
            createPictureInPictureLayout(),
            createMultiMonitorLayout(),
            createStreamingStudioLayout(),
            createWatchPartyLayout(),
            createCompetitiveLayout(),
            createMinimalLayout(),
            createDeveloperLayout(),
            createPresentationLayout(),
            createTournamentLayout()
        ]
    }
    
    /// Get free layout presets
    public static func getFreePresets() -> [Layout] {
        return getAllPresets().filter { !$0.isPremium }
    }
    
    /// Get premium layout presets
    public static func getPremiumPresets() -> [Layout] {
        return getAllPresets().filter { $0.isPremium }
    }
    
    /// Get popular layout presets
    public static func getPopularPresets() -> [Layout] {
        return getAllPresets().filter { $0.isPopular }
    }
    
    // MARK: - Individual Layout Creators
    
    /// Single stream layout - theater mode
    public static func createSingleStreamLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 0
        config.padding = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        config.showControls = true
        config.controlsPosition = .overlay
        config.aspectRatio = 16.0/9.0
        
        let layout = Layout(
            name: "Single Stream",
            type: .theater,
            configuration: config
        )
        
        layout.description = "Perfect for watching one stream in full screen"
        layout.isDefault = true
        layout.tags = ["theater", "single", "fullscreen", "focus"]
        layout.rating = 4.8
        layout.ratingCount = 1250
        layout.downloadCount = 5000
        
        return layout
    }
    
    /// 2x2 grid layout
    public static func createGrid2x2Layout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 8
        config.padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .bottom
        
        let layout = Layout(
            name: "2x2 Grid",
            type: .grid2x2,
            configuration: config
        )
        
        layout.description = "Watch up to 4 streams simultaneously in a balanced grid"
        layout.tags = ["grid", "2x2", "balanced", "popular"]
        layout.rating = 4.6
        layout.ratingCount = 2100
        layout.downloadCount = 8500
        
        return layout
    }
    
    /// 3x3 grid layout
    public static func createGrid3x3Layout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 6
        config.padding = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .overlay
        config.labelFontSize = 12
        
        let layout = Layout(
            name: "3x3 Grid",
            type: .grid3x3,
            configuration: config
        )
        
        layout.description = "Monitor up to 9 streams in a compact grid layout"
        layout.isPremium = true
        layout.tags = ["grid", "3x3", "monitoring", "premium"]
        layout.rating = 4.4
        layout.ratingCount = 850
        layout.downloadCount = 3200
        
        return layout
    }
    
    /// 4x4 grid layout
    public static func createGrid4x4Layout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 4
        config.padding = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        config.aspectRatio = 16.0/9.0
        config.showLabels = false
        config.showControls = false
        config.enableGestures = true
        
        let layout = Layout(
            name: "4x4 Grid",
            type: .grid4x4,
            configuration: config
        )
        
        layout.description = "Maximum streams in a 4x4 grid for serious monitoring"
        layout.isPremium = true
        layout.tags = ["grid", "4x4", "maximum", "monitoring", "premium"]
        layout.rating = 4.2
        layout.ratingCount = 420
        layout.downloadCount = 1800
        
        return layout
    }
    
    /// Vertical stack layout
    public static func createStackLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 12
        config.padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .top
        
        let layout = Layout(
            name: "Vertical Stack",
            type: .stack,
            configuration: config
        )
        
        layout.description = "Stack streams vertically for easy scrolling"
        layout.tags = ["stack", "vertical", "scrolling", "mobile"]
        layout.rating = 4.1
        layout.ratingCount = 680
        layout.downloadCount = 2400
        
        return layout
    }
    
    /// Horizontal carousel layout
    public static func createCarouselLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 16
        config.padding = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .bottom
        config.enableGestures = true
        config.minStreamSize = CGSize(width: 250, height: 140)
        
        let layout = Layout(
            name: "Carousel",
            type: .carousel,
            configuration: config
        )
        
        layout.description = "Swipe through streams horizontally like a carousel"
        layout.tags = ["carousel", "swipe", "horizontal", "browse"]
        layout.rating = 4.3
        layout.ratingCount = 920
        layout.downloadCount = 3600
        
        return layout
    }
    
    /// Focus layout with main stream and thumbnails
    public static func createFocusLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 12
        config.padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .bottom
        config.showControls = true
        config.controlsPosition = .overlay
        
        let layout = Layout(
            name: "Focus Mode",
            type: .focus,
            configuration: config
        )
        
        layout.description = "One main stream with thumbnails on the side"
        layout.tags = ["focus", "main", "thumbnails", "sidebar"]
        layout.rating = 4.7
        layout.ratingCount = 1680
        layout.downloadCount = 6200
        
        return layout
    }
    
    /// Split view layout
    public static func createSplitViewLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 2
        config.padding = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .overlay
        config.enableDragAndDrop = true
        
        let layout = Layout(
            name: "Split View",
            type: .splitView,
            configuration: config
        )
        
        layout.description = "Two streams side by side for comparison"
        layout.isPremium = true
        layout.tags = ["split", "comparison", "dual", "premium"]
        layout.rating = 4.5
        layout.ratingCount = 540
        layout.downloadCount = 2100
        
        return layout
    }
    
    /// Mosaic layout with free positioning
    public static func createMosaicLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 8
        config.padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.enableDragAndDrop = true
        config.snapToGrid = false
        config.enableGestures = true
        config.showLabels = true
        config.labelPosition = .overlay
        
        let layout = Layout(
            name: "Mosaic",
            type: .mosaic,
            configuration: config
        )
        
        layout.description = "Freely position and resize streams anywhere"
        layout.isPremium = true
        layout.tags = ["mosaic", "free", "position", "resize", "premium"]
        layout.rating = 4.4
        layout.ratingCount = 380
        layout.downloadCount = 1500
        
        return layout
    }
    
    /// Theater layout for immersive viewing
    public static func createTheaterLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 0
        config.padding = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        config.backgroundColor = "black"
        config.showControls = true
        config.controlsPosition = .overlay
        config.autoHideControls = true
        config.showLabels = false
        
        let layout = Layout(
            name: "Theater",
            type: .theater,
            configuration: config
        )
        
        layout.description = "Immersive full-screen viewing experience"
        layout.tags = ["theater", "immersive", "fullscreen", "cinema"]
        layout.rating = 4.9
        layout.ratingCount = 2400
        layout.downloadCount = 9800
        
        return layout
    }
    
    /// Dashboard layout with widgets
    public static func createDashboardLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 16
        config.padding = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        config.showLabels = true
        config.labelPosition = .top
        config.showControls = true
        config.controlsPosition = .bottom
        config.enableDragAndDrop = true
        
        let layout = Layout(
            name: "Dashboard",
            type: .dashboard,
            configuration: config
        )
        
        layout.description = "Professional dashboard with stream analytics"
        layout.isPremium = true
        layout.tags = ["dashboard", "professional", "analytics", "premium"]
        layout.rating = 4.6
        layout.ratingCount = 720
        layout.downloadCount = 2800
        
        return layout
    }
    
    /// Picture-in-picture layout
    public static func createPictureInPictureLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 8
        config.padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .bottom
        config.enableGestures = true
        
        let layout = Layout(
            name: "Picture-in-Picture",
            type: .focus,
            configuration: config
        )
        
        layout.description = "Main stream with floating picture-in-picture overlay"
        layout.tags = ["pip", "floating", "overlay", "main"]
        layout.rating = 4.2
        layout.ratingCount = 490
        layout.downloadCount = 1900
        
        return layout
    }
    
    /// Multi-monitor layout for multiple displays
    public static func createMultiMonitorLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 0
        config.padding = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        config.aspectRatio = 21.0/9.0 // Ultrawide aspect ratio
        config.showLabels = true
        config.labelPosition = .overlay
        config.enableDragAndDrop = true
        
        let layout = Layout(
            name: "Multi-Monitor",
            type: .custom,
            configuration: config
        )
        
        layout.description = "Optimized for ultrawide and multi-monitor setups"
        layout.isPremium = true
        layout.tags = ["ultrawide", "multi-monitor", "wide", "premium"]
        layout.rating = 4.3
        layout.ratingCount = 280
        layout.downloadCount = 1200
        
        return layout
    }
    
    /// Streaming studio layout
    public static func createStreamingStudioLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 4
        config.padding = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        config.showLabels = true
        config.labelPosition = .top
        config.showControls = true
        config.controlsPosition = .side
        config.enableDragAndDrop = true
        config.snapToGrid = true
        
        let layout = Layout(
            name: "Streaming Studio",
            type: .custom,
            configuration: config
        )
        
        layout.description = "Professional layout for content creators"
        layout.isPremium = true
        layout.tags = ["studio", "creator", "professional", "premium"]
        layout.rating = 4.7
        layout.ratingCount = 650
        layout.downloadCount = 2500
        
        return layout
    }
    
    /// Watch party layout
    public static func createWatchPartyLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 12
        config.padding = EdgeInsets(top: 16, leading: 16, bottom: 60, trailing: 16)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .bottom
        config.showControls = true
        config.controlsPosition = .bottom
        
        let layout = Layout(
            name: "Watch Party",
            type: .focus,
            configuration: config
        )
        
        layout.description = "Perfect for watching together with friends"
        layout.tags = ["party", "social", "friends", "together"]
        layout.rating = 4.4
        layout.ratingCount = 880
        layout.downloadCount = 3400
        
        return layout
    }
    
    /// Competitive gaming layout
    public static func createCompetitiveLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 1
        config.padding = EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .overlay
        config.labelFontSize = 10
        config.showControls = false
        config.enableGestures = true
        
        let layout = Layout(
            name: "Competitive",
            type: .grid2x2,
            configuration: config
        )
        
        layout.description = "Minimal layout for competitive gaming streams"
        layout.tags = ["competitive", "gaming", "minimal", "esports"]
        layout.rating = 4.5
        layout.ratingCount = 760
        layout.downloadCount = 2900
        
        return layout
    }
    
    /// Minimal layout for distraction-free viewing
    public static func createMinimalLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 8
        config.padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.aspectRatio = 16.0/9.0
        config.showLabels = false
        config.showControls = false
        config.enableGestures = true
        config.backgroundColor = "black"
        
        let layout = Layout(
            name: "Minimal",
            type: .grid2x2,
            configuration: config
        )
        
        layout.description = "Clean and minimal design for focus"
        layout.tags = ["minimal", "clean", "focus", "distraction-free"]
        layout.rating = 4.6
        layout.ratingCount = 520
        layout.downloadCount = 2200
        
        return layout
    }
    
    /// Developer layout for coding streams
    public static func createDeveloperLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 6
        config.padding = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        config.aspectRatio = 16.0/10.0 // Slightly taller for code
        config.showLabels = true
        config.labelPosition = .top
        config.showControls = true
        config.controlsPosition = .overlay
        config.enableDragAndDrop = true
        
        let layout = Layout(
            name: "Developer",
            type: .custom,
            configuration: config
        )
        
        layout.description = "Optimized for coding and development streams"
        layout.isPremium = true
        layout.tags = ["developer", "coding", "programming", "premium"]
        layout.rating = 4.8
        layout.ratingCount = 440
        layout.downloadCount = 1800
        
        return layout
    }
    
    /// Presentation layout
    public static func createPresentationLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 8
        config.padding = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .bottom
        config.showControls = true
        config.controlsPosition = .bottom
        config.enableDragAndDrop = false
        
        let layout = Layout(
            name: "Presentation",
            type: .focus,
            configuration: config
        )
        
        layout.description = "Perfect for presentations and conferences"
        layout.tags = ["presentation", "conference", "business", "formal"]
        layout.rating = 4.3
        layout.ratingCount = 320
        layout.downloadCount = 1400
        
        return layout
    }
    
    /// Tournament layout for esports
    public static func createTournamentLayout() -> Layout {
        let config = LayoutConfiguration()
        config.spacing = 2
        config.padding = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        config.aspectRatio = 16.0/9.0
        config.showLabels = true
        config.labelPosition = .overlay
        config.showControls = false
        config.enableGestures = false
        
        let layout = Layout(
            name: "Tournament",
            type: .custom,
            configuration: config
        )
        
        layout.description = "Multi-stream tournament viewing experience"
        layout.isPremium = true
        layout.tags = ["tournament", "esports", "competitive", "premium"]
        layout.rating = 4.6
        layout.ratingCount = 380
        layout.downloadCount = 1600
        
        return layout
    }
    
    // MARK: - Layout Categories
    
    /// Get layouts by category
    public static func getLayoutsByCategory(_ category: LayoutCategory) -> [Layout] {
        let allLayouts = getAllPresets()
        
        switch category {
        case .gaming:
            return allLayouts.filter { $0.hasTag("gaming") || $0.hasTag("competitive") || $0.hasTag("esports") }
        case .professional:
            return allLayouts.filter { $0.hasTag("professional") || $0.hasTag("studio") || $0.hasTag("business") }
        case .social:
            return allLayouts.filter { $0.hasTag("social") || $0.hasTag("party") || $0.hasTag("friends") }
        case .monitoring:
            return allLayouts.filter { $0.hasTag("monitoring") || $0.hasTag("dashboard") || $0.hasTag("analytics") }
        case .creative:
            return allLayouts.filter { $0.hasTag("creator") || $0.hasTag("developer") || $0.hasTag("presentation") }
        case .entertainment:
            return allLayouts.filter { $0.hasTag("theater") || $0.hasTag("immersive") || $0.hasTag("focus") }
        case .mobile:
            return allLayouts.filter { $0.hasTag("mobile") || $0.hasTag("vertical") || $0.hasTag("stack") }
        case .premium:
            return getPremiumPresets()
        }
    }
    
    /// Get recommended layouts based on user preferences
    public static func getRecommendedLayouts(for preferences: UserPreferences) -> [Layout] {
        var layouts = getAllPresets()
        
        // Filter by subscription status
        if !preferences.hasPremium {
            layouts = layouts.filter { !$0.isPremium }
        }
        
        // Sort by rating and popularity
        layouts.sort { layout1, layout2 in
            if layout1.rating != layout2.rating {
                return layout1.rating > layout2.rating
            }
            return layout1.downloadCount > layout2.downloadCount
        }
        
        // Return top 10 recommended
        return Array(layouts.prefix(10))
    }
}

// MARK: - Supporting Types

public enum LayoutCategory: String, CaseIterable {
    case gaming = "gaming"
    case professional = "professional"
    case social = "social"
    case monitoring = "monitoring"
    case creative = "creative"
    case entertainment = "entertainment"
    case mobile = "mobile"
    case premium = "premium"
    
    public var displayName: String {
        switch self {
        case .gaming: return "Gaming"
        case .professional: return "Professional"
        case .social: return "Social"
        case .monitoring: return "Monitoring"
        case .creative: return "Creative"
        case .entertainment: return "Entertainment"
        case .mobile: return "Mobile"
        case .premium: return "Premium"
        }
    }
    
    public var icon: String {
        switch self {
        case .gaming: return "gamecontroller"
        case .professional: return "briefcase"
        case .social: return "person.2"
        case .monitoring: return "chart.bar"
        case .creative: return "paintbrush"
        case .entertainment: return "tv"
        case .mobile: return "iphone"
        case .premium: return "crown"
        }
    }
}

public struct UserPreferences {
    public let hasPremium: Bool
    public let preferredCategories: [LayoutCategory]
    public let deviceType: DeviceType
    public let usagePatterns: [UsagePattern]
    
    public init(hasPremium: Bool = false, preferredCategories: [LayoutCategory] = [], deviceType: DeviceType = .phone, usagePatterns: [UsagePattern] = []) {
        self.hasPremium = hasPremium
        self.preferredCategories = preferredCategories
        self.deviceType = deviceType
        self.usagePatterns = usagePatterns
    }
}

public enum DeviceType {
    case phone
    case tablet
    case desktop
    case tv
}

public enum UsagePattern {
    case singleStream
    case multiStream
    case backgroundViewing
    case activeMonitoring
    case socialViewing
}