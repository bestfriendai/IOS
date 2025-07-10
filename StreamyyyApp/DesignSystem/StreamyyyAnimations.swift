//
//  StreamyyyAnimations.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Custom animations and micro-interactions for enhanced user experience
//

import SwiftUI

// MARK: - StreamyyyAnimations
struct StreamyyyAnimations {
    
    // MARK: - Standard Animations
    static let quick = Animation.easeInOut(duration: 0.1)
    static let fast = Animation.easeInOut(duration: 0.2)
    static let standard = Animation.easeInOut(duration: 0.3)
    static let slow = Animation.easeInOut(duration: 0.5)
    static let verySlow = Animation.easeInOut(duration: 0.8)
    
    // MARK: - Spring Animations
    static let springQuick = Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
    static let springStandard = Animation.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    static let springBouncy = Animation.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0)
    static let springGentle = Animation.spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0)
    
    // MARK: - Specialized Animations
    static let fadeIn = Animation.easeIn(duration: 0.3)
    static let fadeOut = Animation.easeOut(duration: 0.3)
    static let scaleIn = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let scaleOut = Animation.easeOut(duration: 0.2)
    static let slideIn = Animation.easeOut(duration: 0.4)
    static let slideOut = Animation.easeIn(duration: 0.3)
    
    // MARK: - Gesture Animations
    static let pressDown = Animation.easeInOut(duration: 0.1)
    static let pressUp = Animation.easeInOut(duration: 0.1)
    static let hover = Animation.easeInOut(duration: 0.15)
    static let drag = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.8)
    
    // MARK: - Loading Animations
    static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    static let rotate = Animation.linear(duration: 1.0).repeatForever(autoreverses: false)
    static let breathe = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    
    // MARK: - Transition Animations
    static let pageTransition = Animation.easeInOut(duration: 0.4)
    static let modalPresent = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let modalDismiss = Animation.easeInOut(duration: 0.3)
    static let tabSwitch = Animation.easeInOut(duration: 0.2)
    
    // MARK: - Stream-specific Animations
    static let liveIndicator = Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
    static let streamCardHover = Animation.easeInOut(duration: 0.2)
    static let streamCardPress = Animation.easeInOut(duration: 0.1)
    static let qualityChange = Animation.easeInOut(duration: 0.3)
    static let volumeChange = Animation.easeInOut(duration: 0.2)
    
    // MARK: - Accessibility Animations
    static let accessibilityReduced = Animation.easeInOut(duration: 0.1)
    static let accessibilityStandard = Animation.easeInOut(duration: 0.2)
    
    // MARK: - Custom Animation Functions
    static func customSpring(response: Double, dampingFraction: Double) -> Animation {
        return Animation.spring(response: response, dampingFraction: dampingFraction, blendDuration: 0)
    }
    
    static func customEase(duration: Double) -> Animation {
        return Animation.easeInOut(duration: duration)
    }
    
    static func delayedAnimation(_ animation: Animation, delay: Double) -> Animation {
        return animation.delay(delay)
    }
    
    static func repeatAnimation(_ animation: Animation, count: Int) -> Animation {
        return animation.repeatCount(count, autoreverses: false)
    }
    
    // MARK: - Animation Utilities
    static func withHaptic<T>(_ animation: Animation, hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light, action: () -> T) -> T {
        let generator = UIImpactFeedbackGenerator(style: hapticStyle)
        generator.prepare()
        generator.impactOccurred()
        return withAnimation(animation, action)
    }
    
    static func conditionalAnimation(_ condition: Bool, animation: Animation) -> Animation? {
        return condition ? animation : nil
    }
    
    static func accessibilityAnimation() -> Animation {
        return UIAccessibility.isReduceMotionEnabled ? accessibilityReduced : accessibilityStandard
    }
}

// MARK: - StreamyyyTransition
struct StreamyyyTransition {
    
    // MARK: - Standard Transitions
    static let fade = AnyTransition.opacity
    static let scale = AnyTransition.scale
    static let slide = AnyTransition.slide
    static let move = AnyTransition.move(edge: .bottom)
    
    // MARK: - Custom Transitions
    static let scaleAndFade = AnyTransition.scale.combined(with: .opacity)
    static let slideAndFade = AnyTransition.slide.combined(with: .opacity)
    static let moveAndFade = AnyTransition.move(edge: .bottom).combined(with: .opacity)
    
    // MARK: - Asymmetric Transitions
    static let slideInOut = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )
    
    static let scaleInOut = AnyTransition.asymmetric(
        insertion: .scale.combined(with: .opacity),
        removal: .opacity
    )
    
    static let pushFromRight = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )
    
    static let pushFromLeft = AnyTransition.asymmetric(
        insertion: .move(edge: .leading),
        removal: .move(edge: .trailing)
    )
    
    // MARK: - Modal Transitions
    static let modalPresent = AnyTransition.move(edge: .bottom).combined(with: .opacity)
    static let modalDismiss = AnyTransition.move(edge: .bottom).combined(with: .opacity)
    
    // MARK: - Stream-specific Transitions
    static let streamCardAppear = AnyTransition.scale(scale: 0.8).combined(with: .opacity)
    static let streamCardDisappear = AnyTransition.scale(scale: 1.1).combined(with: .opacity)
    static let liveIndicatorAppear = AnyTransition.scale.combined(with: .opacity)
    
    // MARK: - Custom Transition Functions
    static func customScale(scale: CGFloat) -> AnyTransition {
        return AnyTransition.scale(scale: scale)
    }
    
    static func customMove(edge: Edge) -> AnyTransition {
        return AnyTransition.move(edge: edge)
    }
    
    static func customSlide(edge: Edge) -> AnyTransition {
        return AnyTransition.slide
    }
    
    static func accessibilityTransition() -> AnyTransition {
        return UIAccessibility.isReduceMotionEnabled ? .opacity : .scale.combined(with: .opacity)
    }
}

// MARK: - StreamyyyMicroInteraction
struct StreamyyyMicroInteraction: ViewModifier {
    let style: MicroInteractionStyle
    @State private var isPressed = false
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scaleValue)
            .opacity(opacityValue)
            .brightness(brightnessValue)
            .animation(animationValue, value: isPressed)
            .animation(animationValue, value: isHovered)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
            .onHover { hovering in
                isHovered = hovering
            }
    }
    
    private var scaleValue: CGFloat {
        switch style {
        case .subtle:
            return isPressed ? 0.98 : (isHovered ? 1.02 : 1.0)
        case .standard:
            return isPressed ? 0.95 : (isHovered ? 1.05 : 1.0)
        case .pronounced:
            return isPressed ? 0.90 : (isHovered ? 1.08 : 1.0)
        case .bounce:
            return isPressed ? 0.85 : (isHovered ? 1.1 : 1.0)
        }
    }
    
    private var opacityValue: Double {
        switch style {
        case .subtle:
            return isPressed ? 0.95 : 1.0
        case .standard:
            return isPressed ? 0.9 : 1.0
        case .pronounced:
            return isPressed ? 0.85 : 1.0
        case .bounce:
            return isPressed ? 0.8 : 1.0
        }
    }
    
    private var brightnessValue: Double {
        switch style {
        case .subtle:
            return isHovered ? 0.05 : 0.0
        case .standard:
            return isHovered ? 0.1 : 0.0
        case .pronounced:
            return isHovered ? 0.15 : 0.0
        case .bounce:
            return isHovered ? 0.2 : 0.0
        }
    }
    
    private var animationValue: Animation {
        switch style {
        case .subtle:
            return StreamyyyAnimations.quick
        case .standard:
            return StreamyyyAnimations.fast
        case .pronounced:
            return StreamyyyAnimations.standard
        case .bounce:
            return StreamyyyAnimations.springBouncy
        }
    }
}

// MARK: - MicroInteractionStyle
enum MicroInteractionStyle {
    case subtle
    case standard
    case pronounced
    case bounce
}

// MARK: - StreamyyyPulseEffect
struct StreamyyyPulseEffect: ViewModifier {
    let isActive: Bool
    let color: Color
    let intensity: Double
    @State private var animationAmount = 1.0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .foregroundColor(color)
                    .opacity(isActive ? intensity : 0)
                    .scaleEffect(animationAmount)
                    .animation(
                        isActive ? StreamyyyAnimations.pulse : .none,
                        value: animationAmount
                    )
            )
            .onAppear {
                if isActive {
                    animationAmount = 1.2
                }
            }
    }
}

// MARK: - StreamyyyShimmerEffect
struct StreamyyyShimmerEffect: ViewModifier {
    @State private var isShimmering = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(45))
                    .offset(x: isShimmering ? 200 : -200)
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isShimmering
                    )
            )
            .clipped()
            .onAppear {
                isShimmering = true
            }
    }
}

// MARK: - StreamyyyRotationEffect
struct StreamyyyRotationEffect: ViewModifier {
    let isActive: Bool
    let speed: Double
    @State private var rotation = 0.0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .animation(
                isActive ? Animation.linear(duration: speed).repeatForever(autoreverses: false) : .none,
                value: rotation
            )
            .onAppear {
                if isActive {
                    rotation = 360
                }
            }
    }
}

// MARK: - StreamyyyFloatingEffect
struct StreamyyyFloatingEffect: ViewModifier {
    let isActive: Bool
    let range: CGFloat
    @State private var offset = CGSize.zero
    
    func body(content: Content) -> some View {
        content
            .offset(offset)
            .animation(
                isActive ? Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .none,
                value: offset
            )
            .onAppear {
                if isActive {
                    offset = CGSize(width: 0, height: range)
                }
            }
    }
}

// MARK: - StreamyyyGlowEffect
struct StreamyyyGlowEffect: ViewModifier {
    let isActive: Bool
    let color: Color
    let radius: CGFloat
    @State private var glowIntensity = 0.0
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(glowIntensity), radius: radius)
            .animation(
                isActive ? StreamyyyAnimations.breathe : .none,
                value: glowIntensity
            )
            .onAppear {
                if isActive {
                    glowIntensity = 1.0
                }
            }
    }
}

// MARK: - StreamyyyTypewriterEffect
struct StreamyyyTypewriterEffect: ViewModifier {
    let text: String
    let speed: Double
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    func body(content: Content) -> some View {
        Text(displayedText)
            .onAppear {
                startTypewriter()
            }
            .onChange(of: text) { _ in
                resetTypewriter()
            }
    }
    
    private func startTypewriter() {
        guard currentIndex < text.count else { return }
        
        let index = text.index(text.startIndex, offsetBy: currentIndex)
        displayedText += String(text[index])
        currentIndex += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            startTypewriter()
        }
    }
    
    private func resetTypewriter() {
        displayedText = ""
        currentIndex = 0
        startTypewriter()
    }
}

// MARK: - View Extensions
extension View {
    // MARK: - Micro Interactions
    func microInteraction(_ style: MicroInteractionStyle = .standard) -> some View {
        self.modifier(StreamyyyMicroInteraction(style: style))
    }
    
    // MARK: - Pulse Effect
    func pulseEffect(isActive: Bool, color: Color = StreamyyyColors.primary, intensity: Double = 0.3) -> some View {
        self.modifier(StreamyyyPulseEffect(isActive: isActive, color: color, intensity: intensity))
    }
    
    // MARK: - Shimmer Effect
    func shimmerEffect() -> some View {
        self.modifier(StreamyyyShimmerEffect())
    }
    
    // MARK: - Rotation Effect
    func rotationEffect(isActive: Bool, speed: Double = 1.0) -> some View {
        self.modifier(StreamyyyRotationEffect(isActive: isActive, speed: speed))
    }
    
    // MARK: - Floating Effect
    func floatingEffect(isActive: Bool, range: CGFloat = 10) -> some View {
        self.modifier(StreamyyyFloatingEffect(isActive: isActive, range: range))
    }
    
    // MARK: - Glow Effect
    func glowEffect(isActive: Bool, color: Color = StreamyyyColors.primary, radius: CGFloat = 10) -> some View {
        self.modifier(StreamyyyGlowEffect(isActive: isActive, color: color, radius: radius))
    }
    
    // MARK: - Typewriter Effect
    func typewriterEffect(text: String, speed: Double = 0.05) -> some View {
        self.modifier(StreamyyyTypewriterEffect(text: text, speed: speed))
    }
    
    // MARK: - Conditional Animation
    func conditionalAnimation<T: Equatable>(_ condition: Bool, animation: Animation, value: T) -> some View {
        if condition {
            return self.animation(animation, value: value)
        } else {
            return self.animation(nil, value: value)
        }
    }
    
    // MARK: - Accessibility Animation
    func accessibilityAnimation<T: Equatable>(value: T) -> some View {
        self.animation(StreamyyyAnimations.accessibilityAnimation(), value: value)
    }
    
    // MARK: - Stream-specific Animations
    func streamCardAnimation() -> some View {
        self.microInteraction(.standard)
            .animation(StreamyyyAnimations.streamCardHover, value: UUID())
    }
    
    func liveIndicatorAnimation() -> some View {
        self.pulseEffect(isActive: true, color: StreamyyyColors.liveIndicator)
            .animation(StreamyyyAnimations.liveIndicator, value: UUID())
    }
    
    // MARK: - Press Animation
    func pressAnimation() -> some View {
        self.scaleEffect(1.0)
            .animation(StreamyyyAnimations.pressDown, value: UUID())
    }
    
    // MARK: - Hover Animation
    func hoverAnimation() -> some View {
        self.brightness(0.0)
            .animation(StreamyyyAnimations.hover, value: UUID())
    }
    
    // MARK: - Appear Animation
    func appearAnimation(delay: Double = 0) -> some View {
        self.scaleEffect(0.8)
            .opacity(0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(StreamyyyAnimations.springStandard) {
                        // Animation will be applied when view appears
                    }
                }
            }
    }
    
    // MARK: - Disappear Animation
    func disappearAnimation() -> some View {
        self.transition(StreamyyyTransition.scaleAndFade)
            .animation(StreamyyyAnimations.fadeOut, value: UUID())
    }
}

// MARK: - StreamyyyAnimationPresets
struct StreamyyyAnimationPresets {
    
    // MARK: - Button Animations
    static let buttonPress = StreamyyyAnimations.pressDown
    static let buttonRelease = StreamyyyAnimations.pressUp
    static let buttonHover = StreamyyyAnimations.hover
    
    // MARK: - Card Animations
    static let cardAppear = StreamyyyAnimations.scaleIn
    static let cardDisappear = StreamyyyAnimations.scaleOut
    static let cardHover = StreamyyyAnimations.streamCardHover
    
    // MARK: - Modal Animations
    static let modalPresent = StreamyyyAnimations.modalPresent
    static let modalDismiss = StreamyyyAnimations.modalDismiss
    
    // MARK: - Stream Animations
    static let liveIndicator = StreamyyyAnimations.liveIndicator
    static let qualityChange = StreamyyyAnimations.qualityChange
    static let volumeChange = StreamyyyAnimations.volumeChange
    
    // MARK: - Loading Animations
    static let loadingPulse = StreamyyyAnimations.pulse
    static let loadingRotate = StreamyyyAnimations.rotate
    static let loadingBreathe = StreamyyyAnimations.breathe
    
    // MARK: - Transition Animations
    static let pageTransition = StreamyyyAnimations.pageTransition
    static let tabSwitch = StreamyyyAnimations.tabSwitch
    static let slideTransition = StreamyyyAnimations.slideIn
}

// MARK: - Animation Preview
struct StreamyyyAnimationPreview: View {
    @State private var showPulse = false
    @State private var showRotation = false
    @State private var showFloat = false
    @State private var showGlow = false
    @State private var showShimmer = false
    @State private var typewriterText = "Hello, Streamyyy!"
    
    var body: some View {
        ScrollView {
            VStack(spacing: StreamyyySpacing.lg) {
                Text("Animation Components")
                    .headlineLarge()
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Micro Interactions")
                        .titleMedium()
                    
                    HStack {
                        StreamyyyButton(title: "Subtle") { }
                            .microInteraction(.subtle)
                        
                        StreamyyyButton(title: "Standard") { }
                            .microInteraction(.standard)
                        
                        StreamyyyButton(title: "Bounce") { }
                            .microInteraction(.bounce)
                    }
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Effects")
                        .titleMedium()
                    
                    HStack {
                        StreamyyyCard {
                            Text("Pulse")
                                .bodyMedium()
                                .padding()
                        }
                        .pulseEffect(isActive: showPulse)
                        .onTapGesture {
                            showPulse.toggle()
                        }
                        
                        StreamyyyCard {
                            Text("Rotate")
                                .bodyMedium()
                                .padding()
                        }
                        .rotationEffect(isActive: showRotation)
                        .onTapGesture {
                            showRotation.toggle()
                        }
                        
                        StreamyyyCard {
                            Text("Float")
                                .bodyMedium()
                                .padding()
                        }
                        .floatingEffect(isActive: showFloat)
                        .onTapGesture {
                            showFloat.toggle()
                        }
                    }
                    
                    HStack {
                        StreamyyyCard {
                            Text("Glow")
                                .bodyMedium()
                                .padding()
                        }
                        .glowEffect(isActive: showGlow)
                        .onTapGesture {
                            showGlow.toggle()
                        }
                        
                        StreamyyyCard {
                            Text("Shimmer")
                                .bodyMedium()
                                .padding()
                        }
                        .shimmerEffect()
                        .onTapGesture {
                            showShimmer.toggle()
                        }
                    }
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Live Indicators")
                        .titleMedium()
                    
                    HStack {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .liveIndicatorAnimation()
                            
                            Text("LIVE")
                                .captionMedium()
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        
                        Spacer()
                        
                        Text("Streaming...")
                            .typewriterEffect(text: typewriterText, speed: 0.1)
                            .onTapGesture {
                                typewriterText = "Welcome to Streamyyy!"
                            }
                    }
                }
                
                VStack(spacing: StreamyyySpacing.md) {
                    Text("Stream Cards")
                        .titleMedium()
                    
                    StreamyyyCard {
                        VStack(alignment: .leading, spacing: StreamyyySpacing.sm) {
                            Text("Sample Stream")
                                .titleMedium()
                            
                            Text("This is a sample stream card with animations")
                                .bodySmall()
                                .foregroundColor(StreamyyyColors.textSecondary)
                        }
                        .padding()
                    }
                    .streamCardAnimation()
                }
            }
            .screenPadding()
        }
        .themedBackground()
    }
}

#Preview {
    StreamyyyAnimationPreview()
}