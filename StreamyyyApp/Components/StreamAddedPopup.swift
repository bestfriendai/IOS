//
//  StreamAddedPopup.swift
//  StreamyyyApp
//
//  Created by Streamyyy Team
//  Stream added confirmation popup with navigation options
//

import SwiftUI

struct StreamAddedPopup: View {
    let streamTitle: String
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                StreamyyyColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: StreamyyySpacing.xxl) {
                    Spacer()
                    
                    // Success Icon and Message
                    successSection
                    
                    Spacer()
                    
                    // Action Buttons
                    actionButtons
                    
                    Spacer()
                }
                .screenPadding()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismissPopup()
                    }
                    .font(StreamyyyTypography.labelMedium)
                    .foregroundColor(StreamyyyColors.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            StreamyyyDesignSystem.hapticNotification(.success)
        }
    }
    
    private var successSection: some View {
        VStack(spacing: StreamyyySpacing.lg) {
            // Success Icon with Animation
            ZStack {
                Circle()
                    .fill(StreamyyyColors.success.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(StreamyyyColors.success.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundColor(StreamyyyColors.success)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
            
            // Success Message
            VStack(spacing: StreamyyySpacing.md) {
                Text("Stream Added!")
                    .font(StreamyyyTypography.headlineMedium)
                    .foregroundColor(StreamyyyColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("**\(streamTitle)** has been added to your Multi Stream")
                    .font(StreamyyyTypography.bodyLarge)
                    .foregroundColor(StreamyyyColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Success: \(streamTitle) added to your multi stream")
    }
    
    private var actionButtons: some View {
        VStack(spacing: StreamyyySpacing.md) {
            // Primary Action - Go to Multistreams
            StreamyyyButton(
                title: "Go to Multistreams",
                style: .primary,
                size: .large
            ) {
                goToMultistreams()
            }
            .accessibilityHint("Navigate to your multistream view to see all added streams")
            
            // Secondary Action - Add More Streams
            StreamyyyButton(
                title: "Add More Streams",
                style: .secondary,
                size: .large
            ) {
                addMoreStreams()
            }
            .accessibilityHint("Continue adding more streams to your multistream")
            
            // Tertiary Action - Stay in Discover
            Button("Continue Discovering") {
                dismissPopup()
            }
            .font(StreamyyyTypography.labelMedium)
            .foregroundColor(StreamyyyColors.textSecondary)
            .padding(.top, StreamyyySpacing.sm)
            .accessibilityHint("Stay in the discover view to browse more content")
        }
    }
    
    // MARK: - Actions
    
    private func goToMultistreams() {
        StreamyyyDesignSystem.hapticFeedback(.medium)
        dismissPopup()
        
        // Navigate to multistreams
        // This would typically use a navigation coordinator or state management
        // For now, we'll just dismiss the popup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // TODO: Navigate to MultiStreamView
            // NavigationCoordinator.shared.navigateToMultistreams()
        }
    }
    
    private func addMoreStreams() {
        StreamyyyDesignSystem.hapticFeedback(.light)
        dismissPopup()
        
        // Stay in discover view - user can continue adding streams
        // The popup will dismiss and user remains on discover view
    }
    
    private func dismissPopup() {
        StreamyyyDesignSystem.hapticFeedback(.light)
        isPresented = false
    }
}

// MARK: - Animated Success Icon
struct AnimatedSuccessIcon: View {
    @State private var animationAmount = 0.0
    @State private var checkmarkScale = 0.0
    
    var body: some View {
        ZStack {
            // Outer ring animation
            Circle()
                .stroke(StreamyyyColors.success.opacity(0.3), lineWidth: 2)
                .frame(width: 100, height: 100)
                .scaleEffect(1 + animationAmount)
                .opacity(1 - animationAmount)
                .animation(
                    .easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: animationAmount
                )
            
            // Inner circle
            Circle()
                .fill(StreamyyyColors.success.opacity(0.1))
                .frame(width: 80, height: 80)
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50, weight: .medium))
                .foregroundColor(StreamyyyColors.success)
                .scaleEffect(checkmarkScale)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: checkmarkScale)
        }
        .onAppear {
            animationAmount = 1.0
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                checkmarkScale = 1.0
            }
        }
    }
}

// MARK: - Compact Stream Added Toast
struct StreamAddedToast: View {
    let streamTitle: String
    @Binding var isVisible: Bool
    
    var body: some View {
        HStack(spacing: StreamyyySpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: StreamyyySpacing.iconSizeMD, weight: .medium))
                .foregroundColor(StreamyyyColors.success)
            
            VStack(alignment: .leading, spacing: StreamyyySpacing.xs) {
                Text("Stream Added")
                    .font(StreamyyyTypography.labelMedium)
                    .foregroundColor(StreamyyyColors.textPrimary)
                
                Text(streamTitle)
                    .font(StreamyyyTypography.captionLarge)
                    .foregroundColor(StreamyyyColors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                StreamyyyDesignSystem.hapticFeedback(.light)
                isVisible = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: StreamyyySpacing.iconSizeSM, weight: .medium))
                    .foregroundColor(StreamyyyColors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(StreamyyySpacing.md)
        .background(
            StreamyyyCard(style: .success, shadowStyle: .elevated) {
                EmptyView()
            }
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stream added: \(streamTitle)")
        .accessibilityHint("Tap X to dismiss this notification")
    }
}

// MARK: - Previews
#Preview("Stream Added Popup") {
    StreamAddedPopup(
        streamTitle: "shroud - VALORANT",
        isPresented: .constant(true)
    )
}

#Preview("Animated Success Icon") {
    AnimatedSuccessIcon()
        .padding()
        .background(StreamyyyColors.background)
}

#Preview("Stream Added Toast") {
    VStack {
        Spacer()
        
        StreamAddedToast(
            streamTitle: "xQc - Grand Theft Auto V",
            isVisible: .constant(true)
        )
        .padding()
        
        Spacer()
    }
    .background(StreamyyyColors.background)
}