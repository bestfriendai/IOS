//
//  TransitionAnimations.swift
//  StreamyyyApp
//
//  Enhanced transition animations for seamless navigation
//

import SwiftUI

// MARK: - Custom Transitions
extension AnyTransition {
    
    /// Smooth slide transition with opacity
    static var smoothSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    /// Push transition (like UINavigationController)
    static var push: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        )
    }
    
    /// Modal presentation transition
    static var modalPresentation: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    /// Custom spring transition
    static var springSlide: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: SpringTransitionModifier(offset: 100, opacity: 0),
                identity: SpringTransitionModifier(offset: 0, opacity: 1)
            ),
            removal: .modifier(
                active: SpringTransitionModifier(offset: -100, opacity: 0),
                identity: SpringTransitionModifier(offset: 0, opacity: 1)
            )
        )
    }
}

// MARK: - Spring Transition Modifier
struct SpringTransitionModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
    }
}

// MARK: - Navigation Transition Style
enum NavigationTransitionStyle {
    case slide
    case fade
    case scale
    case push
    case modal
    case spring
    
    var transition: AnyTransition {
        switch self {
        case .slide:
            return .smoothSlide
        case .fade:
            return .opacity
        case .scale:
            return .scaleAndFade
        case .push:
            return .push
        case .modal:
            return .modalPresentation
        case .spring:
            return .springSlide
        }
    }
    
    var animation: Animation {
        switch self {
        case .slide:
            return .easeInOut(duration: 0.3)
        case .fade:
            return .easeInOut(duration: 0.25)
        case .scale:
            return .spring(response: 0.4, dampingFraction: 0.8)
        case .push:
            return .easeInOut(duration: 0.35)
        case .modal:
            return .spring(response: 0.5, dampingFraction: 0.9)
        case .spring:
            return .spring(response: 0.6, dampingFraction: 0.8)
        }
    }
}

// MARK: - Tab Transition Effects
struct TabTransitionModifier: ViewModifier {
    let selectedTab: Int
    let currentTab: Int
    
    func body(content: Content) -> some View {
        content
            .opacity(selectedTab == currentTab ? 1.0 : 0.3)
            .scaleEffect(selectedTab == currentTab ? 1.0 : 0.95)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
    }
}

// MARK: - Hero Transition for Stream Cards
struct HeroTransitionModifier: ViewModifier {
    let isExpanded: Bool
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(id: "hero", in: namespace, properties: .frame)
            .scaleEffect(isExpanded ? 1.1 : 1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - Floating Action Button Transition
struct FloatingActionTransition: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isVisible ? 1.0 : 0.0)
            .opacity(isVisible ? 1.0 : 0.0)
            .rotationEffect(.degrees(isVisible ? 0 : 180))
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isVisible)
    }
}

// MARK: - Navigation Path Transition
struct NavigationPathTransition: ViewModifier {
    let depth: Int
    
    private var offset: CGFloat {
        CGFloat(depth) * 20
    }
    
    private var opacity: Double {
        max(0.3, 1.0 - Double(depth) * 0.1)
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(opacity)
            .animation(.easeInOut(duration: 0.3), value: depth)
    }
}

// MARK: - View Extensions for Transitions
extension View {
    
    /// Apply tab transition effect
    func tabTransition(selectedTab: Int, currentTab: Int) -> some View {
        modifier(TabTransitionModifier(selectedTab: selectedTab, currentTab: currentTab))
    }
    
    /// Apply hero transition effect
    func heroTransition(isExpanded: Bool, namespace: Namespace.ID) -> some View {
        modifier(HeroTransitionModifier(isExpanded: isExpanded, namespace: namespace))
    }
    
    /// Apply floating action button transition
    func floatingActionTransition(isVisible: Bool) -> some View {
        modifier(FloatingActionTransition(isVisible: isVisible))
    }
    
    /// Apply navigation path transition
    func navigationPathTransition(depth: Int) -> some View {
        modifier(NavigationPathTransition(depth: depth))
    }
    
    /// Apply smooth transition with custom style
    func smoothTransition(style: NavigationTransitionStyle = .slide) -> some View {
        self.transition(style.transition)
    }
    
    /// Animate navigation changes
    func animateNavigation<T: Equatable>(_ value: T, style: NavigationTransitionStyle = .slide) -> some View {
        self.animation(style.animation, value: value)
    }
}

// MARK: - Custom Animation Curves
extension Animation {
    
    /// Smooth entrance animation
    static var smoothEntrance: Animation {
        .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2)
    }
    
    /// Quick exit animation
    static var quickExit: Animation {
        .easeInOut(duration: 0.2)
    }
    
    /// Bouncy spring animation
    static var bouncySpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.3)
    }
    
    /// Gentle slide animation
    static var gentleSlide: Animation {
        .timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.4)
    }
    
    /// Navigation animation
    static var navigation: Animation {
        .timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.3)
    }
}

// MARK: - Interactive Transition Gesture
struct InteractiveTransitionGesture: ViewModifier {
    @State private var dragOffset = CGSize.zero
    @State private var isInteracting = false
    let onDismiss: () -> Void
    
    func body(content: Content) -> some View {
        content
            .offset(dragOffset)
            .scaleEffect(isInteracting ? 0.95 : 1.0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isInteracting {
                            isInteracting = true
                        }
                        
                        // Only allow downward drag for dismissal
                        if value.translation.y > 0 {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isInteracting = false
                            
                            if value.translation.y > 100 || value.predictedEndTranslation.y > 200 {
                                onDismiss()
                            } else {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isInteracting)
    }
}

extension View {
    func interactiveDismissGesture(onDismiss: @escaping () -> Void) -> some View {
        modifier(InteractiveTransitionGesture(onDismiss: onDismiss))
    }
}

// MARK: - Preview
struct TransitionAnimations_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Transition Animations")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Enhanced navigation transitions")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Example transitions
            HStack(spacing: 20) {
                Rectangle()
                    .fill(.blue.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .smoothTransition(style: .scale)
                
                Rectangle()
                    .fill(.green.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .smoothTransition(style: .slide)
                
                Rectangle()
                    .fill(.orange.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .smoothTransition(style: .spring)
            }
        }
        .padding()
    }
}