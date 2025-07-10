//
//  StreamyyySpacing.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Comprehensive spacing and layout system
//

import SwiftUI

// MARK: - StreamyyySpacing
struct StreamyyySpacing {
    
    // MARK: - Base Spacing Units
    static let baseUnit: CGFloat = 8
    
    // MARK: - Spacing Scale
    static let xxxs: CGFloat = baseUnit * 0.5    // 4pt
    static let xxs: CGFloat = baseUnit * 0.75    // 6pt
    static let xs: CGFloat = baseUnit * 1        // 8pt
    static let sm: CGFloat = baseUnit * 1.5      // 12pt
    static let md: CGFloat = baseUnit * 2        // 16pt
    static let lg: CGFloat = baseUnit * 3        // 24pt
    static let xl: CGFloat = baseUnit * 4        // 32pt
    static let xxl: CGFloat = baseUnit * 5       // 40pt
    static let xxxl: CGFloat = baseUnit * 6      // 48pt
    
    // MARK: - Semantic Spacing
    static let micro = xxxs     // 4pt
    static let tiny = xxs       // 6pt
    static let small = xs       // 8pt
    static let medium = sm      // 12pt
    static let regular = md     // 16pt
    static let large = lg       // 24pt
    static let xlarge = xl      // 32pt
    static let xxlarge = xxl    // 40pt
    static let xxxlarge = xxxl  // 48pt
    
    // MARK: - Component Spacing
    static let buttonPadding = md               // 16pt
    static let buttonSpacing = sm               // 12pt
    static let cardPadding = md                 // 16pt
    static let cardSpacing = sm                 // 12pt
    static let sectionSpacing = lg              // 24pt
    static let contentSpacing = md              // 16pt
    static let itemSpacing = xs                 // 8pt
    
    // MARK: - Layout Spacing
    static let screenPadding = md               // 16pt
    static let screenSpacing = lg               // 24pt
    static let containerPadding = md            // 16pt
    static let containerSpacing = lg            // 24pt
    static let gridSpacing = sm                 // 12pt
    static let listSpacing = xs                 // 8pt
    
    // MARK: - Navigation Spacing
    static let navigationPadding = md           // 16pt
    static let navigationSpacing = sm           // 12pt
    static let tabBarPadding = xs               // 8pt
    static let tabBarSpacing = sm               // 12pt
    
    // MARK: - Stream Interface Spacing
    static let streamCardPadding = sm           // 12pt
    static let streamCardSpacing = md           // 16pt
    static let streamControlPadding = xs        // 8pt
    static let streamControlSpacing = sm        // 12pt
    static let streamGridSpacing = md           // 16pt
    static let streamListSpacing = xs           // 8pt
    
    // MARK: - Form Spacing
    static let formPadding = md                 // 16pt
    static let formSpacing = lg                 // 24pt
    static let fieldPadding = sm                // 12pt
    static let fieldSpacing = md                // 16pt
    static let inputPadding = sm                // 12pt
    
    // MARK: - Overlay Spacing
    static let overlayPadding = md              // 16pt
    static let overlaySpacing = lg              // 24pt
    static let modalPadding = lg                // 24pt
    static let modalSpacing = xl                // 32pt
    
    // MARK: - Corner Radius
    static let cornerRadiusXS: CGFloat = 4
    static let cornerRadiusSM: CGFloat = 8
    static let cornerRadiusMD: CGFloat = 12
    static let cornerRadiusLG: CGFloat = 16
    static let cornerRadiusXL: CGFloat = 20
    static let cornerRadiusXXL: CGFloat = 24
    
    // MARK: - Semantic Corner Radius
    static let buttonCornerRadius = cornerRadiusSM      // 8pt
    static let cardCornerRadius = cornerRadiusMD        // 12pt
    static let modalCornerRadius = cornerRadiusLG       // 16pt
    static let imageCornerRadius = cornerRadiusSM       // 8pt
    static let overlayCornerRadius = cornerRadiusMD     // 12pt
    
    // MARK: - Stream Component Corner Radius
    static let streamCardCornerRadius = cornerRadiusMD  // 12pt
    static let streamThumbnailCornerRadius = cornerRadiusSM // 8pt
    static let streamControlCornerRadius = cornerRadiusXS   // 4pt
    static let streamBadgeCornerRadius = cornerRadiusXS     // 4pt
    
    // MARK: - Shadow and Elevation
    static let shadowRadiusXS: CGFloat = 2
    static let shadowRadiusSM: CGFloat = 4
    static let shadowRadiusMD: CGFloat = 8
    static let shadowRadiusLG: CGFloat = 16
    static let shadowRadiusXL: CGFloat = 24
    
    // MARK: - Semantic Shadow
    static let cardShadowRadius = shadowRadiusSM        // 4pt
    static let modalShadowRadius = shadowRadiusLG       // 16pt
    static let buttonShadowRadius = shadowRadiusXS      // 2pt
    static let overlayShadowRadius = shadowRadiusMD     // 8pt
    
    // MARK: - Border Width
    static let borderWidthThin: CGFloat = 0.5
    static let borderWidthRegular: CGFloat = 1
    static let borderWidthMedium: CGFloat = 2
    static let borderWidthThick: CGFloat = 3
    
    // MARK: - Semantic Border Width
    static let cardBorderWidth = borderWidthThin        // 0.5pt
    static let buttonBorderWidth = borderWidthRegular   // 1pt
    static let inputBorderWidth = borderWidthRegular    // 1pt
    static let separatorWidth = borderWidthThin         // 0.5pt
    
    // MARK: - Icon Sizes
    static let iconSizeXS: CGFloat = 12
    static let iconSizeSM: CGFloat = 16
    static let iconSizeMD: CGFloat = 20
    static let iconSizeLG: CGFloat = 24
    static let iconSizeXL: CGFloat = 32
    static let iconSizeXXL: CGFloat = 40
    
    // MARK: - Semantic Icon Sizes
    static let buttonIconSize = iconSizeSM              // 16pt
    static let navigationIconSize = iconSizeMD          // 20pt
    static let tabBarIconSize = iconSizeLG              // 24pt
    static let cardIconSize = iconSizeMD                // 20pt
    static let statusIconSize = iconSizeSM              // 16pt
    
    // MARK: - Stream Icon Sizes
    static let streamControlIconSize = iconSizeSM       // 16pt
    static let streamStatusIconSize = iconSizeXS        // 12pt
    static let streamPlatformIconSize = iconSizeSM      // 16pt
    static let streamActionIconSize = iconSizeMD        // 20pt
    
    // MARK: - Minimum Touch Targets
    static let minimumTouchTarget: CGFloat = 44
    static let recommendedTouchTarget: CGFloat = 48
    
    // MARK: - Responsive Spacing
    static func responsive(base: CGFloat, scale: CGFloat = 1.0) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let referenceWidth: CGFloat = 375 // iPhone 12 mini width
        let scaleFactor = screenWidth / referenceWidth
        return base * scaleFactor * scale
    }
    
    // MARK: - Safe Area Spacing
    static var safeAreaTop: CGFloat {
        guard let window = UIApplication.shared.windows.first else { return 0 }
        return window.safeAreaInsets.top
    }
    
    static var safeAreaBottom: CGFloat {
        guard let window = UIApplication.shared.windows.first else { return 0 }
        return window.safeAreaInsets.bottom
    }
    
    static var safeAreaLeading: CGFloat {
        guard let window = UIApplication.shared.windows.first else { return 0 }
        return window.safeAreaInsets.left
    }
    
    static var safeAreaTrailing: CGFloat {
        guard let window = UIApplication.shared.windows.first else { return 0 }
        return window.safeAreaInsets.right
    }
    
    // MARK: - Device Specific Spacing
    static var deviceSpecificPadding: CGFloat {
        let deviceType = UIDevice.current.userInterfaceIdiom
        switch deviceType {
        case .phone:
            return md
        case .pad:
            return xl
        default:
            return md
        }
    }
    
    static var deviceSpecificSpacing: CGFloat {
        let deviceType = UIDevice.current.userInterfaceIdiom
        switch deviceType {
        case .phone:
            return lg
        case .pad:
            return xxl
        default:
            return lg
        }
    }
    
    // MARK: - Accessibility Spacing
    static var accessibilitySpacing: CGFloat {
        return UIAccessibility.isReduceMotionEnabled ? md : lg
    }
    
    static var accessibilityTouchTarget: CGFloat {
        return UIAccessibility.isReduceMotionEnabled ? minimumTouchTarget : recommendedTouchTarget
    }
}

// MARK: - View Extensions for Spacing
extension View {
    // MARK: - Padding Extensions
    func paddingXS() -> some View {
        self.padding(StreamyyySpacing.xs)
    }
    
    func paddingSM() -> some View {
        self.padding(StreamyyySpacing.sm)
    }
    
    func paddingMD() -> some View {
        self.padding(StreamyyySpacing.md)
    }
    
    func paddingLG() -> some View {
        self.padding(StreamyyySpacing.lg)
    }
    
    func paddingXL() -> some View {
        self.padding(StreamyyySpacing.xl)
    }
    
    func paddingXXL() -> some View {
        self.padding(StreamyyySpacing.xxl)
    }
    
    // MARK: - Directional Padding
    func paddingHorizontal(_ spacing: CGFloat) -> some View {
        self.padding(.horizontal, spacing)
    }
    
    func paddingVertical(_ spacing: CGFloat) -> some View {
        self.padding(.vertical, spacing)
    }
    
    func paddingTop(_ spacing: CGFloat) -> some View {
        self.padding(.top, spacing)
    }
    
    func paddingBottom(_ spacing: CGFloat) -> some View {
        self.padding(.bottom, spacing)
    }
    
    func paddingLeading(_ spacing: CGFloat) -> some View {
        self.padding(.leading, spacing)
    }
    
    func paddingTrailing(_ spacing: CGFloat) -> some View {
        self.padding(.trailing, spacing)
    }
    
    // MARK: - Semantic Padding
    func screenPadding() -> some View {
        self.padding(StreamyyySpacing.screenPadding)
    }
    
    func containerPadding() -> some View {
        self.padding(StreamyyySpacing.containerPadding)
    }
    
    func cardPadding() -> some View {
        self.padding(StreamyyySpacing.cardPadding)
    }
    
    func buttonPadding() -> some View {
        self.padding(StreamyyySpacing.buttonPadding)
    }
    
    func contentPadding() -> some View {
        self.padding(StreamyyySpacing.contentSpacing)
    }
    
    // MARK: - Corner Radius Extensions
    func cornerRadiusXS() -> some View {
        self.cornerRadius(StreamyyySpacing.cornerRadiusXS)
    }
    
    func cornerRadiusSM() -> some View {
        self.cornerRadius(StreamyyySpacing.cornerRadiusSM)
    }
    
    func cornerRadiusMD() -> some View {
        self.cornerRadius(StreamyyySpacing.cornerRadiusMD)
    }
    
    func cornerRadiusLG() -> some View {
        self.cornerRadius(StreamyyySpacing.cornerRadiusLG)
    }
    
    func cornerRadiusXL() -> some View {
        self.cornerRadius(StreamyyySpacing.cornerRadiusXL)
    }
    
    // MARK: - Semantic Corner Radius
    func buttonCornerRadius() -> some View {
        self.cornerRadius(StreamyyySpacing.buttonCornerRadius)
    }
    
    func cardCornerRadius() -> some View {
        self.cornerRadius(StreamyyySpacing.cardCornerRadius)
    }
    
    func modalCornerRadius() -> some View {
        self.cornerRadius(StreamyyySpacing.modalCornerRadius)
    }
    
    func imageCornerRadius() -> some View {
        self.cornerRadius(StreamyyySpacing.imageCornerRadius)
    }
    
    // MARK: - Shadow Extensions
    func cardShadow() -> some View {
        self.shadow(
            color: StreamyyyColors.overlay.opacity(0.1),
            radius: StreamyyySpacing.cardShadowRadius,
            x: 0,
            y: 2
        )
    }
    
    func modalShadow() -> some View {
        self.shadow(
            color: StreamyyyColors.overlay.opacity(0.2),
            radius: StreamyyySpacing.modalShadowRadius,
            x: 0,
            y: 8
        )
    }
    
    func buttonShadow() -> some View {
        self.shadow(
            color: StreamyyyColors.overlay.opacity(0.15),
            radius: StreamyyySpacing.buttonShadowRadius,
            x: 0,
            y: 1
        )
    }
    
    func overlayShadow() -> some View {
        self.shadow(
            color: StreamyyyColors.overlay.opacity(0.25),
            radius: StreamyyySpacing.overlayShadowRadius,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - Minimum Touch Target
    func minimumTouchTarget() -> some View {
        self.frame(minWidth: StreamyyySpacing.minimumTouchTarget, minHeight: StreamyyySpacing.minimumTouchTarget)
    }
    
    func recommendedTouchTarget() -> some View {
        self.frame(minWidth: StreamyyySpacing.recommendedTouchTarget, minHeight: StreamyyySpacing.recommendedTouchTarget)
    }
    
    // MARK: - Responsive Spacing
    func responsivePadding(base: CGFloat, scale: CGFloat = 1.0) -> some View {
        let responsiveSpacing = StreamyyySpacing.responsive(base: base, scale: scale)
        return self.padding(responsiveSpacing)
    }
    
    // MARK: - Safe Area Aware Padding
    func safeAreaAwarePadding() -> some View {
        self.padding(.top, StreamyyySpacing.safeAreaTop)
            .padding(.bottom, StreamyyySpacing.safeAreaBottom)
            .padding(.leading, StreamyyySpacing.safeAreaLeading)
            .padding(.trailing, StreamyyySpacing.safeAreaTrailing)
    }
    
    // MARK: - Device Specific Spacing
    func deviceSpecificPadding() -> some View {
        self.padding(StreamyyySpacing.deviceSpecificPadding)
    }
    
    func deviceSpecificSpacing() -> some View {
        self.padding(StreamyyySpacing.deviceSpecificSpacing)
    }
}

// MARK: - Spacer Extensions
extension Spacer {
    static func xs() -> some View {
        Spacer().frame(height: StreamyyySpacing.xs)
    }
    
    static func sm() -> some View {
        Spacer().frame(height: StreamyyySpacing.sm)
    }
    
    static func md() -> some View {
        Spacer().frame(height: StreamyyySpacing.md)
    }
    
    static func lg() -> some View {
        Spacer().frame(height: StreamyyySpacing.lg)
    }
    
    static func xl() -> some View {
        Spacer().frame(height: StreamyyySpacing.xl)
    }
    
    static func xxl() -> some View {
        Spacer().frame(height: StreamyyySpacing.xxl)
    }
}

// MARK: - SwiftUI Environment Key
private struct StreamyyySpacingKey: EnvironmentKey {
    static let defaultValue = StreamyyySpacing.self
}

extension EnvironmentValues {
    var streamyyySpacing: StreamyyySpacing.Type {
        get { self[StreamyyySpacingKey.self] }
        set { self[StreamyyySpacingKey.self] = newValue }
    }
}