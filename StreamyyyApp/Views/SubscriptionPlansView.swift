//
//  SubscriptionPlansView.swift
//  StreamyyyApp
//
//  Comprehensive subscription plans view with features, pricing, and comparison
//

import SwiftUI
import Stripe

struct SubscriptionPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.stripeManager) private var stripeManager
    
    @State private var selectedPlan: SubscriptionPlan = .premium
    @State private var selectedBillingInterval: BillingInterval = .monthly
    @State private var isProcessing = false
    @State private var showingPaymentSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingPromoCode = false
    @State private var promoCode = ""
    @State private var promoDiscount: Double = 0.0
    @State private var promoError: String?
    
    private let plans: [SubscriptionPlan] = [.basic, .premium, .pro, .enterprise]
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundGradient
                
                ScrollView {
                    VStack(spacing: 30) {
                        headerSection
                        billingIntervalSelector
                        plansGrid
                        promoCodeSection
                        comparisonSection
                        continueButton
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Your Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingPaymentSheet) {
            PaymentSheetView(
                plan: selectedPlan,
                billingInterval: selectedBillingInterval,
                promoCode: promoCode.isEmpty ? nil : promoCode,
                promoDiscount: promoDiscount
            )
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.95)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Unlock Premium Features")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("Get unlimited streams, advanced layouts, and premium support")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Billing Interval Selector
    
    private var billingIntervalSelector: some View {
        VStack(spacing: 16) {
            Text("Choose Billing Cycle")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 0) {
                ForEach(BillingInterval.allCases, id: \.self) { interval in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedBillingInterval = interval
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(interval.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if interval == .yearly {
                                Text("Save \(interval.discountPercentage)%")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedBillingInterval == interval ? 
                            Color.purple.opacity(0.1) : Color.clear
                        )
                        .foregroundColor(
                            selectedBillingInterval == interval ? 
                            .purple : .primary
                        )
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Plans Grid
    
    private var plansGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(plans, id: \.self) { plan in
                PlanCard(
                    plan: plan,
                    billingInterval: selectedBillingInterval,
                    isSelected: selectedPlan == plan,
                    isCurrentPlan: subscriptionManager?.currentPlan == plan
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPlan = plan
                    }
                }
            }
        }
    }
    
    // MARK: - Promo Code Section
    
    private var promoCodeSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingPromoCode.toggle()
            }) {
                HStack {
                    Image(systemName: "tag.fill")
                    Text("Have a promo code?")
                    Spacer()
                    Image(systemName: showingPromoCode ? "chevron.up" : "chevron.down")
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            if showingPromoCode {
                VStack(spacing: 8) {
                    HStack {
                        TextField("Enter promo code", text: $promoCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textCase(.uppercase)
                            .autocorrectionDisabled()
                        
                        Button("Apply") {
                            applyPromoCode()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(promoCode.isEmpty)
                    }
                    
                    if let promoError = promoError {
                        Text(promoError)
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if promoDiscount > 0 {
                        Text("Discount applied: \(Int(promoDiscount))% off")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
    
    // MARK: - Comparison Section
    
    private var comparisonSection: some View {
        VStack(spacing: 16) {
            Text("Feature Comparison")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.fixed(40)),
                GridItem(.fixed(40)),
                GridItem(.fixed(40)),
                GridItem(.fixed(40))
            ], spacing: 8) {
                // Header
                Text("Features")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(plans, id: \.self) { plan in
                    Text(plan.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Features
                ForEach(allFeatures, id: \.self) { feature in
                    Text(feature.displayName)
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    ForEach(plans, id: \.self) { plan in
                        Image(systemName: plan.features.contains(feature) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(plan.features.contains(feature) ? .green : .red)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        VStack(spacing: 16) {
            if let currentSubscription = subscriptionManager?.currentSubscription {
                if currentSubscription.plan == selectedPlan {
                    Button("Current Plan") {
                        // Do nothing - already on this plan
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                } else {
                    Button(selectedPlan.rawValue.compare(currentSubscription.plan.rawValue) == .orderedDescending ? "Upgrade Plan" : "Change Plan") {
                        changePlan()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                }
            } else {
                Button("Start Free Trial") {
                    startSubscription()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
            
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
            }
            
            VStack(spacing: 4) {
                Text("7-day free trial • Cancel anytime")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Helper Properties
    
    private var allFeatures: [SubscriptionFeature] {
        Array(Set(plans.flatMap { $0.features })).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - Actions
    
    private func startSubscription() {
        isProcessing = true
        
        Task {
            do {
                try await subscriptionManager?.subscribe(
                    to: selectedPlan,
                    billingInterval: selectedBillingInterval
                )
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func changePlan() {
        isProcessing = true
        
        Task {
            do {
                try await subscriptionManager?.changePlan(to: selectedPlan)
                
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func applyPromoCode() {
        guard !promoCode.isEmpty else { return }
        
        Task {
            do {
                // Validate promo code through Stripe
                let discount = try await stripeManager.validatePromoCode(promoCode)
                
                await MainActor.run {
                    promoDiscount = discount
                    promoError = nil
                }
            } catch {
                await MainActor.run {
                    promoError = error.localizedDescription
                    promoDiscount = 0.0
                }
            }
        }
    }
}

// MARK: - Plan Card

struct PlanCard: View {
    let plan: SubscriptionPlan
    let billingInterval: BillingInterval
    let isSelected: Bool
    let isCurrentPlan: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text(plan.displayName)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if isCurrentPlan {
                        Text("Current")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.purple)
                    }
                }
                
                // Price
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .bottom) {
                        Text("$\(String(format: "%.2f", plan.price(for: billingInterval)))")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("/" + billingInterval.displayName.lowercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if billingInterval == .yearly {
                        Text("Save \(billingInterval.discountPercentage)%")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Description
                Text(plan.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)
                
                // Key Features
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.features.prefix(3), id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(feature.displayName)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if plan.features.count > 3 {
                        Text("+ \(plan.features.count - 3) more features")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? plan.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? plan.color : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Payment Sheet View

struct PaymentSheetView: View {
    let plan: SubscriptionPlan
    let billingInterval: BillingInterval
    let promoCode: String?
    let promoDiscount: Double
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.subscriptionManager) private var subscriptionManager
    @Environment(\.stripeManager) private var stripeManager
    
    @State private var isProcessing = false
    @State private var paymentComplete = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Summary
                VStack(spacing: 16) {
                    Text("Payment Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text(plan.displayName)
                            Spacer()
                            Text("$\(String(format: "%.2f", plan.price(for: billingInterval)))")
                        }
                        
                        if promoDiscount > 0 {
                            HStack {
                                Text("Discount (\(Int(promoDiscount))%)")
                                    .foregroundColor(.green)
                                Spacer()
                                Text("-$\(String(format: "%.2f", plan.price(for: billingInterval) * promoDiscount / 100))")
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("$\(String(format: "%.2f", finalPrice))")
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                // Payment Button
                Button(action: processPayment) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Complete Purchase")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isProcessing)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Payment Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Payment Successful", isPresented: $paymentComplete) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Your subscription has been activated successfully!")
        }
    }
    
    private var finalPrice: Double {
        let originalPrice = plan.price(for: billingInterval)
        let discount = originalPrice * promoDiscount / 100
        return originalPrice - discount
    }
    
    private func processPayment() {
        isProcessing = true
        
        Task {
            do {
                try await subscriptionManager?.subscribe(
                    to: plan,
                    billingInterval: billingInterval
                )
                
                await MainActor.run {
                    isProcessing = false
                    paymentComplete = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionPlansView()
        .environment(\.subscriptionManager, nil)
        .environment(\.stripeManager, StripeManager.shared)
}