//
//  SubscriptionManagementView.swift
//  StreamyyyApp
//
//  Real subscription management with Stripe integration
//

import SwiftUI

struct SubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    
    @State private var selectedPlan: SubscriptionPlan = .premium
    @State private var selectedInterval: BillingInterval = .monthly
    @State private var showingCancelConfirmation = false
    @State private var showingPlanChange = false
    @State private var showingBillingHistory = false
    @State private var showingPaymentMethods = false
    @State private var promoCode = ""
    @State private var isApplyingPromo = false
    @State private var promoMessage = ""
    @State private var showingPromoAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if subscriptionManager.isSubscribed {
                        currentSubscriptionCard
                        subscriptionDetailsCard
                        managementActionsCard
                        billingInformationCard
                    } else {
                        subscriptionPlansCard
                        featuresComparisonCard
                    }
                    
                    promoCodeCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(backgroundGradient)
            .navigationTitle(subscriptionManager.isSubscribed ? "Manage Subscription" : "Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingBillingHistory) {
            BillingHistoryView()
        }
        .sheet(isPresented: $showingPaymentMethods) {
            PaymentMethodsView()
        }
        .alert("Cancel Subscription", isPresented: $showingCancelConfirmation) {
            Button("Keep Subscription", role: .cancel) { }
            Button("Cancel", role: .destructive) {
                cancelSubscription()
            }
        } message: {
            Text("Are you sure you want to cancel your subscription? You'll lose access to premium features at the end of your billing period.")
        }
        .alert("Promo Code", isPresented: $showingPromoAlert) {
            Button("OK") { }
        } message: {
            Text(promoMessage)
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Current Subscription Card
    private var currentSubscriptionCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                        
                        Text(subscriptionManager.subscriptionDisplayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("Active Subscription")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(subscriptionManager.formattedSubscriptionPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("per \\(subscriptionManager.currentSubscription?.billingInterval.displayName.lowercased() ?? "month")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            if subscriptionManager.isInTrial {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    
                    Text("\\(subscriptionManager.trialDaysRemaining) days left in free trial")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Subscription Details Card
    private var subscriptionDetailsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Subscription Details")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                DetailRow(
                    title: "Next Billing Date",
                    value: subscriptionManager.formattedNextBillingDate,
                    icon: "calendar"
                )
                
                DetailRow(
                    title: "Billing Interval",
                    value: subscriptionManager.currentSubscription?.billingInterval.displayName ?? "Monthly",
                    icon: "clock"
                )
                
                DetailRow(
                    title: "Status",
                    value: subscriptionManager.subscriptionHealth.displayName,
                    icon: "checkmark.shield",
                    valueColor: subscriptionManager.subscriptionHealth.color
                )
                
                if subscriptionManager.hasActiveDiscount,
                   let discountDescription = subscriptionManager.discountDescription {
                    DetailRow(
                        title: "Active Discount",
                        value: discountDescription,
                        icon: "tag",
                        valueColor: .green
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Management Actions Card
    private var managementActionsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Manage Subscription")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                if subscriptionManager.canChangeBillingInterval {
                    ManagementButton(
                        title: "Change Billing Frequency",
                        subtitle: "Switch between monthly and yearly",
                        icon: "arrow.triangle.2.circlepath",
                        action: {
                            showingPlanChange = true
                        }
                    )
                }
                
                ManagementButton(
                    title: "Payment Methods",
                    subtitle: "Update your payment information",
                    icon: "creditcard",
                    action: {
                        showingPaymentMethods = true
                    }
                )
                
                ManagementButton(
                    title: "Billing History",
                    subtitle: "View past payments and invoices",
                    icon: "doc.text",
                    action: {
                        showingBillingHistory = true
                    }
                )
                
                if subscriptionManager.canPauseSubscription {
                    ManagementButton(
                        title: "Pause Subscription",
                        subtitle: "Temporarily pause your subscription",
                        icon: "pause.circle",
                        action: {
                            pauseSubscription()
                        }
                    )
                } else if subscriptionManager.canResumeSubscription {
                    ManagementButton(
                        title: "Resume Subscription",
                        subtitle: "Resume your paused subscription",
                        icon: "play.circle",
                        action: {
                            resumeSubscription()
                        }
                    )
                }
                
                ManagementButton(
                    title: "Cancel Subscription",
                    subtitle: "Cancel your subscription",
                    icon: "xmark.circle",
                    isDestructive: true,
                    action: {
                        showingCancelConfirmation = true
                    }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Billing Information Card
    private var billingInformationCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Billing Information")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Edit") {
                    showingPaymentMethods = true
                }
                .font(.subheadline)
                .foregroundColor(.cyan)
            }
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("•••• •••• •••• 1234")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        Text("Expires 12/25")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text("Visa")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24)
                    
                    Text(profileManager.userEmail ?? "No email")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Subscription Plans Card (for non-subscribers)
    private var subscriptionPlansCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
                
                Text("Upgrade to StreamHub Pro")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Unlock unlimited streaming and premium features")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            // Plan Selection
            VStack(spacing: 12) {
                ForEach(SubscriptionPlan.allCases.filter { $0 != .free }, id: \.self) { plan in
                    PlanSelectionCard(
                        plan: plan,
                        isSelected: selectedPlan == plan,
                        selectedInterval: selectedInterval,
                        onSelect: {
                            selectedPlan = plan
                        }
                    )
                }
            }
            
            // Billing Interval Toggle
            VStack(spacing: 12) {
                Text("Billing Interval")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    IntervalToggle(
                        interval: .monthly,
                        isSelected: selectedInterval == .monthly,
                        onSelect: { selectedInterval = .monthly }
                    )
                    
                    IntervalToggle(
                        interval: .yearly,
                        isSelected: selectedInterval == .yearly,
                        onSelect: { selectedInterval = .yearly }
                    )
                }
            }
            
            // Subscribe Button
            Button(action: subscribe) {
                VStack(spacing: 4) {
                    Text("Start 7-Day Free Trial")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Then \\(selectedPlan.price(for: selectedInterval), specifier: "%.2f")/\\(selectedInterval.displayName.lowercased())")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(subscriptionManager.isLoading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Features Comparison Card
    private var featuresComparisonCard: some View {
        VStack(spacing: 16) {
            Text("What's Included")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                FeatureItem(icon: "infinity", title: "Unlimited Streams", description: "Watch as many streams as you want")
                FeatureItem(icon: "hd.circle.fill", title: "4K Quality", description: "Stream in ultra-high definition")
                FeatureItem(icon: "bell.fill", title: "Live Notifications", description: "Never miss when streamers go live")
                FeatureItem(icon: "heart.fill", title: "Unlimited Favorites", description: "Save all your favorite content")
                FeatureItem(icon: "rectangle.on.rectangle", title: "Picture in Picture", description: "Watch while using other apps")
                FeatureItem(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Detailed viewing statistics")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Promo Code Card
    private var promoCodeCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Promo Code")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                TextField("Enter promo code", text: $promoCode)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .foregroundColor(.white)
                    .autocapitalization(.allCharacters)
                
                Button(action: applyPromoCode) {
                    if isApplyingPromo {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Apply")
                    }
                }
                .disabled(promoCode.isEmpty || isApplyingPromo)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(promoCode.isEmpty ? Color.gray : Color.cyan)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Methods
    private func subscribe() {
        Task {
            do {
                try await subscriptionManager.subscribe(to: selectedPlan, billingInterval: selectedInterval)
            } catch {
                print("Subscription failed: \\(error)")
            }
        }
    }
    
    private func cancelSubscription() {
        Task {
            do {
                try await subscriptionManager.cancelSubscription(reason: "User requested cancellation")
            } catch {
                print("Cancellation failed: \\(error)")
            }
        }
    }
    
    private func pauseSubscription() {
        Task {
            do {
                try await subscriptionManager.pauseSubscription()
            } catch {
                print("Pause failed: \\(error)")
            }
        }
    }
    
    private func resumeSubscription() {
        Task {
            do {
                try await subscriptionManager.resumeSubscription()
            } catch {
                print("Resume failed: \\(error)")
            }
        }
    }
    
    private func applyPromoCode() {
        guard !promoCode.isEmpty else { return }
        
        isApplyingPromo = true
        
        Task {
            do {
                if let subscription = subscriptionManager.currentSubscription {
                    try await subscriptionManager.applyPromoCode(promoCode, to: subscription.id)
                    promoMessage = "Promo code applied successfully!"
                } else {
                    let discount = try await subscriptionManager.validatePromoCode(promoCode)
                    promoMessage = "Valid promo code! \\(Int(discount * 100))% discount will be applied."
                }
                
                promoCode = ""
                showingPromoAlert = true
                isApplyingPromo = false
            } catch {
                promoMessage = "Invalid or expired promo code."
                showingPromoAlert = true
                isApplyingPromo = false
            }
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .white
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

struct ManagementButton: View {
    let title: String
    let subtitle: String
    let icon: String
    var isDestructive = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? .red : .cyan)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PlanSelectionCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let selectedInterval: BillingInterval
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(plan.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if plan == .pro {
                            Text("POPULAR")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.yellow.opacity(0.2))
                                )
                        }
                    }
                    
                    Text(plan.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\\(plan.price(for: selectedInterval), specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("per \\(selectedInterval.displayName.lowercased())")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? plan.color : .white.opacity(0.4))
                    .font(.title3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? plan.color.opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? plan.color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct IntervalToggle: View {
    let interval: BillingInterval
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Text(interval.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .black : .white)
                
                if interval == .yearly {
                    Text("Save \\(interval.discountPercentage)%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .green : .green.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.cyan : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Additional Views (Placeholders for now)

struct BillingHistoryView: View {
    var body: some View {
        NavigationView {
            Text("Billing History")
                .navigationTitle("Billing History")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PaymentMethodsView: View {
    var body: some View {
        NavigationView {
            Text("Payment Methods")
                .navigationTitle("Payment Methods")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SubscriptionManagementView()
}"