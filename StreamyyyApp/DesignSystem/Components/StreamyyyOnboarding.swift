//
//  StreamyyyOnboarding.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Enhanced onboarding flow with animations and modern design
//

import SwiftUI

// MARK: - StreamyyyOnboarding
struct StreamyyyOnboarding: View {
    @State private var currentPage = 0
    @State private var showingApp = false
    @Environment(\.dismiss) private var dismiss
    
    private let pages = OnboardingPage.allPages
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    StreamyyyColors.primary.opacity(0.1),
                    StreamyyyColors.accent.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Page indicator
                HStack {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? StreamyyyColors.primary : StreamyyyColors.border)
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(StreamyyyAnimations.springStandard, value: currentPage)
                    }
                }
                .padding(.top, StreamyyySpacing.lg)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(StreamyyyAnimations.pageTransition, value: currentPage)
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        StreamyyyButton(
                            title: "Back",
                            style: .ghost,
                            size: .medium
                        ) {
                            withAnimation(StreamyyyAnimations.pageTransition) {
                                currentPage -= 1
                            }
                        }
                    } else {
                        Spacer()
                    }
                    
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        StreamyyyButton(
                            title: "Next",
                            style: .primary,
                            size: .medium
                        ) {
                            withAnimation(StreamyyyAnimations.pageTransition) {
                                currentPage += 1
                            }
                        }
                    } else {
                        StreamyyyButton(
                            title: "Get Started",
                            style: .primary,
                            size: .large
                        ) {
                            completeOnboarding()
                        }
                    }
                }
                .padding(.horizontal, StreamyyySpacing.lg)
                .padding(.bottom, StreamyyySpacing.xl)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(false)
        .onAppear {
            setupOnboarding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Onboarding flow")
        .accessibilityHint("Swipe to navigate between pages")
    }
    
    private func setupOnboarding() {
        // Configure for onboarding
        StreamyyyAccessibility.screenChangedNotification()
    }
    
    private func completeOnboarding() {
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "onboarding_completed")
        
        // Dismiss with animation
        withAnimation(StreamyyyAnimations.modalDismiss) {
            dismiss()
        }
        
        // Announce completion
        StreamyyyAccessibility.announceForAccessibility("Onboarding completed. Welcome to Streamyyy!")
    }
}

// MARK: - OnboardingPageView
struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: StreamyyySpacing.xxl) {
            Spacer()
            
            // Animation area
            ZStack {
                // Background elements
                ForEach(page.backgroundElements, id: \.id) { element in
                    OnboardingAnimationElement(element: element, isAnimating: $isAnimating)
                }
                
                // Main illustration
                OnboardingIllustration(
                    iconName: page.iconName,
                    color: page.color,
                    isAnimating: $isAnimating
                )
            }
            .frame(height: 200)
            .onAppear {
                withAnimation(StreamyyyAnimations.springGentle.delay(0.5)) {
                    isAnimating = true
                }
            }
            
            Spacer()
            
            // Content
            VStack(spacing: StreamyyySpacing.lg) {
                Text(page.title)
                    .headlineLarge()
                    .foregroundColor(StreamyyyColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .typewriterEffect(text: page.title, speed: 0.05)
                    .accessibilityAddTraits(.isHeader)
                
                Text(page.description)
                    .bodyLarge()
                    .foregroundColor(StreamyyyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, StreamyyySpacing.lg)
                    .lineLimit(nil)
                    .accessibilityHint("Page description")
                
                // Features list
                if !page.features.isEmpty {
                    VStack(alignment: .leading, spacing: StreamyyySpacing.md) {
                        ForEach(page.features, id: \.self) { feature in
                            HStack(spacing: StreamyyySpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(page.color)
                                    .font(.system(size: StreamyyySpacing.iconSizeSM))
                                
                                Text(feature)
                                    .bodyMedium()
                                    .foregroundColor(StreamyyyColors.textPrimary)
                            }
                            .appearAnimation(delay: Double(page.features.firstIndex(of: feature) ?? 0) * 0.1)
                        }
                    }
                    .padding(.horizontal, StreamyyySpacing.lg)
                }
            }
            
            Spacer()
        }
        .padding(StreamyyySpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(page.title)
        .accessibilityHint(page.description)
    }
}

// MARK: - OnboardingIllustration
struct OnboardingIllustration: View {
    let iconName: String
    let color: Color
    @Binding var isAnimating: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .animation(StreamyyyAnimations.springGentle, value: isAnimating)
            
            // Main icon
            Image(systemName: iconName)
                .font(.system(size: 60, weight: .light))
                .foregroundColor(color)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(StreamyyyAnimations.springGentle.delay(0.2), value: isAnimating)
                .floatingEffect(isActive: isAnimating, range: 5)
        }
        .glowEffect(isActive: isAnimating, color: color, radius: 20)
    }
}

// MARK: - OnboardingAnimationElement
struct OnboardingAnimationElement: View {
    let element: BackgroundElement
    @Binding var isAnimating: Bool
    
    var body: some View {
        Image(systemName: element.iconName)
            .font(.system(size: element.size, weight: .light))
            .foregroundColor(element.color.opacity(0.3))
            .position(element.position)
            .scaleEffect(isAnimating ? 1.0 : 0.5)
            .opacity(isAnimating ? 1.0 : 0.0)
            .animation(
                StreamyyyAnimations.springGentle.delay(element.delay),
                value: isAnimating
            )
            .floatingEffect(isActive: isAnimating, range: element.floatRange)
    }
}

// MARK: - OnboardingPage
struct OnboardingPage {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let color: Color
    let features: [String]
    let backgroundElements: [BackgroundElement]
    
    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            title: "Welcome to Streamyyy",
            description: "Your ultimate destination for multi-stream viewing. Watch multiple live streams simultaneously with our powerful and intuitive interface.",
            iconName: "play.tv.fill",
            color: StreamyyyColors.primary,
            features: [
                "Multi-stream viewing",
                "Real-time synchronization",
                "Intuitive interface"
            ],
            backgroundElements: [
                BackgroundElement(
                    iconName: "tv.fill",
                    size: 24,
                    color: StreamyyyColors.accent,
                    position: CGPoint(x: 80, y: 40),
                    delay: 0.3,
                    floatRange: 3
                ),
                BackgroundElement(
                    iconName: "play.circle.fill",
                    size: 18,
                    color: StreamyyyColors.secondary,
                    position: CGPoint(x: 280, y: 60),
                    delay: 0.5,
                    floatRange: 4
                ),
                BackgroundElement(
                    iconName: "video.fill",
                    size: 20,
                    color: StreamyyyColors.accent,
                    position: CGPoint(x: 320, y: 140),
                    delay: 0.4,
                    floatRange: 2
                )
            ]
        ),
        
        OnboardingPage(
            title: "Discover Live Streams",
            description: "Explore trending streams from Twitch, YouTube, and other platforms. Find your favorite streamers and discover new content.",
            iconName: "magnifyingglass.circle.fill",
            color: StreamyyyColors.accent,
            features: [
                "Multiple platforms",
                "Real-time search",
                "Trending content",
                "Personalized recommendations"
            ],
            backgroundElements: [
                BackgroundElement(
                    iconName: "star.fill",
                    size: 16,
                    color: StreamyyyColors.primary,
                    position: CGPoint(x: 60, y: 80),
                    delay: 0.2,
                    floatRange: 3
                ),
                BackgroundElement(
                    iconName: "heart.fill",
                    size: 14,
                    color: StreamyyyColors.error,
                    position: CGPoint(x: 300, y: 50),
                    delay: 0.4,
                    floatRange: 2
                ),
                BackgroundElement(
                    iconName: "flame.fill",
                    size: 18,
                    color: StreamyyyColors.warning,
                    position: CGPoint(x: 90, y: 160),
                    delay: 0.6,
                    floatRange: 4
                )
            ]
        ),
        
        OnboardingPage(
            title: "Customize Your Layout",
            description: "Create your perfect viewing experience with customizable layouts. Choose from various grid options and arrange streams to your liking.",
            iconName: "rectangle.grid.2x2.fill",
            color: StreamyyyColors.secondary,
            features: [
                "Flexible grid layouts",
                "Drag & drop arrangement",
                "Save custom layouts",
                "Responsive design"
            ],
            backgroundElements: [
                BackgroundElement(
                    iconName: "square.grid.2x2.fill",
                    size: 20,
                    color: StreamyyyColors.primary,
                    position: CGPoint(x: 70, y: 60),
                    delay: 0.3,
                    floatRange: 2
                ),
                BackgroundElement(
                    iconName: "rectangle.grid.3x2.fill",
                    size: 16,
                    color: StreamyyyColors.accent,
                    position: CGPoint(x: 290, y: 100),
                    delay: 0.5,
                    floatRange: 3
                ),
                BackgroundElement(
                    iconName: "square.grid.3x3.fill",
                    size: 14,
                    color: StreamyyyColors.secondary,
                    position: CGPoint(x: 110, y: 170),
                    delay: 0.4,
                    floatRange: 2
                )
            ]
        ),
        
        OnboardingPage(
            title: "Professional Controls",
            description: "Enjoy professional-grade streaming controls with gesture support, quality selection, and advanced audio management.",
            iconName: "slider.horizontal.3",
            color: StreamyyyColors.success,
            features: [
                "Gesture controls",
                "Quality selection",
                "Audio management",
                "Picture-in-picture"
            ],
            backgroundElements: [
                BackgroundElement(
                    iconName: "speaker.wave.2.fill",
                    size: 18,
                    color: StreamyyyColors.primary,
                    position: CGPoint(x: 80, y: 40),
                    delay: 0.2,
                    floatRange: 3
                ),
                BackgroundElement(
                    iconName: "gear.circle.fill",
                    size: 16,
                    color: StreamyyyColors.accent,
                    position: CGPoint(x: 280, y: 80),
                    delay: 0.4,
                    floatRange: 2
                ),
                BackgroundElement(
                    iconName: "hand.tap.fill",
                    size: 20,
                    color: StreamyyyColors.secondary,
                    position: CGPoint(x: 320, y: 150),
                    delay: 0.6,
                    floatRange: 4
                )
            ]
        ),
        
        OnboardingPage(
            title: "Ready to Stream!",
            description: "You're all set to begin your multi-stream journey. Start exploring, discover amazing content, and enjoy seamless streaming.",
            iconName: "checkmark.circle.fill",
            color: StreamyyyColors.success,
            features: [
                "Everything is ready",
                "Start streaming now",
                "Enjoy the experience"
            ],
            backgroundElements: [
                BackgroundElement(
                    iconName: "party.popper.fill",
                    size: 24,
                    color: StreamyyyColors.primary,
                    position: CGPoint(x: 100, y: 50),
                    delay: 0.2,
                    floatRange: 5
                ),
                BackgroundElement(
                    iconName: "sparkles",
                    size: 18,
                    color: StreamyyyColors.accent,
                    position: CGPoint(x: 260, y: 70),
                    delay: 0.4,
                    floatRange: 3
                ),
                BackgroundElement(
                    iconName: "crown.fill",
                    size: 20,
                    color: StreamyyyColors.warning,
                    position: CGPoint(x: 320, y: 130),
                    delay: 0.6,
                    floatRange: 4
                )
            ]
        )
    ]
}

// MARK: - BackgroundElement
struct BackgroundElement {
    let id = UUID()
    let iconName: String
    let size: CGFloat
    let color: Color
    let position: CGPoint
    let delay: Double
    let floatRange: CGFloat
}

// MARK: - StreamyyyOnboardingManager
class StreamyyyOnboardingManager: ObservableObject {
    @Published var shouldShowOnboarding = false
    @Published var hasSeenOnboarding = false
    
    private let onboardingCompletedKey = "onboarding_completed"
    private let onboardingVersionKey = "onboarding_version"
    private let currentOnboardingVersion = "1.0"
    
    init() {
        checkOnboardingStatus()
    }
    
    func checkOnboardingStatus() {
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
        let completedVersion = UserDefaults.standard.string(forKey: onboardingVersionKey)
        
        // Show onboarding if never completed or version changed
        shouldShowOnboarding = !hasCompletedOnboarding || completedVersion != currentOnboardingVersion
        hasSeenOnboarding = hasCompletedOnboarding
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        UserDefaults.standard.set(currentOnboardingVersion, forKey: onboardingVersionKey)
        
        shouldShowOnboarding = false
        hasSeenOnboarding = true
    }
    
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        UserDefaults.standard.removeObject(forKey: onboardingVersionKey)
        
        shouldShowOnboarding = true
        hasSeenOnboarding = false
    }
}

// MARK: - StreamyyyOnboardingButton
struct StreamyyyOnboardingButton: View {
    @StateObject private var onboardingManager = StreamyyyOnboardingManager()
    @State private var showingOnboarding = false
    
    var body: some View {
        StreamyyyButton(
            title: "View Onboarding",
            style: .secondary,
            size: .medium,
            action: {
                showingOnboarding = true
            }
        )
        .fullScreenCover(isPresented: $showingOnboarding) {
            StreamyyyOnboarding()
        }
    }
}

// MARK: - Onboarding Preview
struct StreamyyyOnboardingPreview: View {
    var body: some View {
        VStack(spacing: StreamyyySpacing.lg) {
            Text("Onboarding Components")
                .headlineLarge()
            
            Text("Preview the onboarding flow")
                .bodyMedium()
                .foregroundColor(StreamyyyColors.textSecondary)
            
            StreamyyyOnboardingButton()
            
            Spacer()
        }
        .screenPadding()
        .themedBackground()
    }
}

#Preview {
    StreamyyyOnboardingPreview()
}